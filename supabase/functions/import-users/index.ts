import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const allowedRoles = new Set([
  "superadministrador", "administrador_general", "encargado_frente",
  "encargado_stock", "mecanico", "chofer",
]);

function errorMessage(error: unknown) {
  if (error instanceof Error) return error.message;
  if (error && typeof error === "object" && "message" in error) return String((error as { message?: unknown }).message || "Error desconocido");
  return String(error || "Error desconocido");
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const authHeader = request.headers.get("Authorization") || "";
    const url = Deno.env.get("SUPABASE_URL")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const callerClient = createClient(url, anonKey, { global: { headers: { Authorization: authHeader } } });
    const { data: authData, error: authError } = await callerClient.auth.getUser();
    if (authError || !authData.user) throw new Error("Sesión no válida");

    const { data: caller, error: callerError } = await callerClient.from("profiles").select("role,active").eq("id", authData.user.id).single();
    if (callerError) throw new Error(`No se pudo verificar el perfil: ${callerError.message}`);
    const body = await request.json();
    const isSuperAdmin = caller?.active && caller.role === "superadministrador";
    const isGeneralAdmin = caller?.active && caller.role === "administrador_general";
    const isUserEdit = ["update-user", "set-user-active"].includes(String(body.action || ""));
    if (!isSuperAdmin && !(isGeneralAdmin && isUserEdit)) {
      return Response.json({ error: isUserEdit ? "Solo administradores habilitados pueden editar usuarios" : "Solo el superadministrador puede importar usuarios" }, { status: 403, headers: corsHeaders });
    }

    const admin = createClient(url, serviceKey, { auth: { persistSession: false } });

    if (body.action === "update-user") {
      const targetId = String(body.targetId || "");
      const role = String(body.role || "");
      if (!targetId || !allowedRoles.has(role)) throw new Error("Usuario o rol inválido");
      const { data: target, error: targetError } = await admin.from("profiles").select("id,role,active").eq("id", targetId).single();
      if (targetError || !target) throw new Error(targetError?.message || "El usuario no existe");
      if (!isSuperAdmin && ["superadministrador", "administrador_general"].includes(target.role)) {
        return Response.json({ error: "Solo el superadministrador puede editar administradores" }, { status: 403, headers: corsHeaders });
      }
      if (!isSuperAdmin && ["superadministrador", "administrador_general"].includes(role)) {
        return Response.json({ error: "Solo el superadministrador puede asignar roles administrativos" }, { status: 403, headers: corsHeaders });
      }
      const active = body.active !== false;
      if (targetId === authData.user.id && (role !== "superadministrador" || !active)) {
        throw new Error("No puedes quitarte el rol de superadministrador ni desactivar tu propia cuenta");
      }
      const username = String(body.username || "").trim().toLowerCase();
      const fullName = String(body.fullName || "").trim();
      if (!username || !fullName) throw new Error("Usuario y nombre son obligatorios");
      const profileUpdate = await admin.from("profiles").update({
        username,
        full_name: fullName,
        phone: String(body.phone || "").trim() || null,
        role,
        active,
        hourly_rate: Math.max(0, Number(body.hourlyRate || 0)),
        hourly_currency: body.currency === "USD" ? "USD" : "UYU",
        updated_at: new Date().toISOString(),
      }).eq("id", targetId);
      if (profileUpdate.error) throw profileUpdate.error;
      const authUpdate = await admin.auth.admin.updateUserById(targetId, {
        ban_duration: active ? "none" : "876000h",
        user_metadata: { username, full_name: fullName },
      });
      if (authUpdate.error) throw authUpdate.error;

      const normalize = (value: unknown) => String(value || "").normalize("NFD").replace(/[\u0300-\u036f]/g, "").trim().toLowerCase();
      const { data: companies } = await admin.from("companies").select("id,name");
      const { data: areas } = await admin.from("areas").select("id,name,company_id");
      const { data: locations } = await admin.from("locations").select("id,name,company_id");
      const wantedCompanies = new Set((body.companies || []).map(normalize));
      const companyIds = (companies || []).filter(c => wantedCompanies.has(normalize(c.name))).map(c => c.id);
      const wantedAreas = new Set((body.areas || []).map(normalize));
      const areaIds = (areas || []).filter(a => wantedAreas.has(normalize(a.name)) && (!companyIds.length || companyIds.includes(a.company_id))).map(a => a.id);
      const wantedLocations = new Set((body.locations || []).map(normalize));
      const locationIds = (locations || []).filter(l => wantedLocations.has(normalize(l.name)) && (!companyIds.length || companyIds.includes(l.company_id))).map(l => l.id);
      await Promise.all([
        admin.from("profile_companies").delete().eq("profile_id", targetId),
        admin.from("profile_areas").delete().eq("profile_id", targetId),
        admin.from("profile_locations").delete().eq("profile_id", targetId),
      ]);
      if (companyIds.length) {
        const result = await admin.from("profile_companies").insert(companyIds.map(company_id => ({ profile_id: targetId, company_id })));
        if (result.error) throw result.error;
      }
      if (areaIds.length) {
        const result = await admin.from("profile_areas").insert(areaIds.map(area_id => ({ profile_id: targetId, area_id })));
        if (result.error) throw result.error;
      }
      if (locationIds.length) {
        const result = await admin.from("profile_locations").insert(locationIds.map(location_id => ({ profile_id: targetId, location_id })));
        if (result.error) throw result.error;
      }
      return Response.json({ ok: true }, { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }
    if (body.action === "set-user-active") {
      const targetId = String(body.targetId || "");
      const active = body.active === true;
      if (!targetId) throw new Error("Usuario inválido");
      if (targetId === authData.user.id && !active) throw new Error("No puedes desactivar tu propia cuenta");
      const { data: target, error: targetError } = await admin.from("profiles").select("role").eq("id", targetId).single();
      if (targetError || !target) throw new Error(targetError?.message || "El usuario no existe");
      if (!isSuperAdmin && ["superadministrador", "administrador_general"].includes(target.role)) {
        return Response.json({ error: "Solo el superadministrador puede desactivar administradores" }, { status: 403, headers: corsHeaders });
      }
      const profileUpdate = await admin.from("profiles").update({ active, updated_at: new Date().toISOString() }).eq("id", targetId);
      if (profileUpdate.error) throw profileUpdate.error;
      const authUpdate = await admin.auth.admin.updateUserById(targetId, { ban_duration: active ? "none" : "876000h" });
      if (authUpdate.error) throw authUpdate.error;
      return Response.json({ ok: true }, { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }
    if (body.action === "resolve-password") {
      const requestId = String(body.requestId || "");
      const decision = body.decision === "approved" ? "approved" : body.decision === "rejected" ? "rejected" : "";
      if (!requestId || !decision) throw new Error("Solicitud o decisión inválida");
      const { data: resetRequest, error: resetError } = await admin.from("password_reset_requests").select("id,username,status,notes").eq("id", requestId).single();
      if (resetError || !resetRequest) throw new Error(resetError?.message || "La solicitud no existe");
      if (resetRequest.status !== "pendiente") throw new Error("La solicitud ya fue revisada");
      if (decision === "approved") {
        const password = String(body.password || "");
        if (password.length < 8) throw new Error("La contraseña debe tener al menos 8 caracteres");
        const { data: target, error: targetError } = await admin.from("profiles").select("id,username").eq("username", resetRequest.username).single();
        if (targetError || !target) throw new Error("No se encontró el usuario solicitado");
        const changed = await admin.auth.admin.updateUserById(target.id, { password });
        if (changed.error) throw changed.error;
      }
      const responseNote = String(body.note || (decision === "approved" ? "Contraseña actualizada por el superadministrador" : "Solicitud rechazada"));
      const { error: updateError } = await admin.from("password_reset_requests").update({ status: decision === "approved" ? "atendida" : "cancelada", resolved_at: new Date().toISOString(), resolved_by: authData.user.id, notes: responseNote }).eq("id", requestId);
      if (updateError) throw updateError;
      return Response.json({ ok: true }, { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }
    const rows = Array.isArray(body.users) ? body.users.slice(0, 250) : [];
    const results: Array<Record<string, unknown>> = [];
    const { data: companies } = await admin.from("companies").select("id,name");
    const { data: areas } = await admin.from("areas").select("id,name,company_id");
    const { data: locations } = await admin.from("locations").select("id,name,company_id");
    const normalize = (value: unknown) => String(value || "").normalize("NFD").replace(/[\u0300-\u036f]/g, "").trim().toLowerCase();

    for (const row of rows) {
      let createdId = "";
      try {
        if (!row.email || !row.username || !row.fullName || !allowedRoles.has(row.role)) throw new Error("Datos obligatorios inválidos");
        if (String(row.password || "").length < 8) throw new Error("La contraseña temporal debe tener al menos 8 caracteres");
        const created = await admin.auth.admin.createUser({ email: row.email, password: row.password, email_confirm: true, user_metadata: { username: row.username, full_name: row.fullName } });
        if (created.error) throw created.error;
        createdId = created.data.user.id;
        const profile = await admin.from("profiles").upsert({ id: createdId, username: row.username, full_name: row.fullName, phone: row.phone || null, role: row.role, active: row.active !== false, hourly_rate: Number(row.hourlyRate || 0), hourly_currency: row.currency === "USD" ? "USD" : "UYU", must_change_password: true });
        if (profile.error) throw profile.error;

        const wantedCompanies = new Set((row.companies || []).map(normalize));
        const companyIds = (companies || []).filter(c => wantedCompanies.has(normalize(c.name))).map(c => c.id);
        const wantedAreas = new Set((row.areas || []).map(normalize));
        const areaIds = (areas || []).filter(a => wantedAreas.has(normalize(a.name)) && (!companyIds.length || companyIds.includes(a.company_id))).map(a => a.id);
        const wantedLocations = new Set((row.locations || []).map(normalize));
        const locationIds = (locations || []).filter(l => wantedLocations.has(normalize(l.name)) && (!companyIds.length || companyIds.includes(l.company_id))).map(l => l.id);
        if (companyIds.length) await admin.from("profile_companies").upsert(companyIds.map(company_id => ({ profile_id: createdId, company_id })));
        if (areaIds.length) await admin.from("profile_areas").upsert(areaIds.map(area_id => ({ profile_id: createdId, area_id })));
        if (locationIds.length) await admin.from("profile_locations").upsert(locationIds.map(location_id => ({ profile_id: createdId, location_id })));
        results.push({ row: row.row, email: row.email, username: row.username, ok: true });
      } catch (error) {
        if (createdId) await admin.auth.admin.deleteUser(createdId);
        console.error("import-users row failed", row.row, errorMessage(error));
        results.push({ row: row.row, email: row.email, username: row.username, ok: false, error: errorMessage(error) });
      }
    }
    return Response.json({ results }, { headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (error) {
    console.error("import-users request failed", errorMessage(error));
    return Response.json({ error: errorMessage(error) }, { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
