// =====================================================================
// Findout Jornada · Edge Function "bloquear-aluno"
// Bloqueia ou libera o login de um aluno, a pedido de um administrador.
// Nada é apagado: XP, moedas, progresso e perfil ficam intactos, e ao
// liberar a pessoa volta exatamente de onde parou.
//
// Como publicar: Supabase → Edge Functions → Deploy a new function →
// nome "bloquear-aluno" → colar este arquivo → Deploy ("Verify JWT" ligado).
// =====================================================================
import { createClient } from "npm:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const url = Deno.env.get("SUPABASE_URL")!;
    const service = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

    // Quem chamou precisa estar logado e ser admin
    const comToken = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, {
      global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
    });
    const { data: { user } } = await comToken.auth.getUser();
    if (!user) return json(401, { erro: "Sessão expirada. Saia e entre de novo." });
    const { data: adm } = await service.from("admins").select("user_id").eq("user_id", user.id).maybeSingle();
    if (!adm) return json(403, { erro: "Só administradores podem bloquear ou liberar contas." });

    const { user_id, bloquear } = await req.json().catch(() => ({}));
    if (!user_id || typeof bloquear !== "boolean") return json(400, { erro: "Pedido incompleto." });
    if (user_id === user.id) return json(400, { erro: "Você não pode bloquear a si mesmo." });
    if (bloquear) {
      const { data: alvoAdm } = await service.from("admins").select("user_id").eq("user_id", user_id).maybeSingle();
      if (alvoAdm) return json(400, { erro: "Esse usuário é administrador. Tire o acesso ao painel antes de bloquear." });
    }

    // ban_duration longa = bloqueado; "none" = liberado. Não apaga nada.
    const { error } = await service.auth.admin.updateUserById(user_id, {
      ban_duration: bloquear ? "876000h" : "none",
    });
    if (error) return json(400, { erro: error.message });
    return json(200, { ok: true });
  } catch (e) {
    return json(500, { erro: "Erro inesperado: " + String(e) });
  }
});
