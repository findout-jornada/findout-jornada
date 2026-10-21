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
  if (req.method !== "POST") return json(405, { erro: "Método não permitido." });
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
    if (!/^[0-9a-f-]{36}$/i.test(String(user_id))) return json(400, { erro: "Identificador inválido." });
    if (user_id === user.id) return json(400, { erro: "Você não pode bloquear a si mesmo." });
    if (bloquear) {
      const { data: alvoAdm } = await service.from("admins").select("user_id").eq("user_id", user_id).maybeSingle();
      if (alvoAdm) return json(400, { erro: "Esse usuário é administrador. Tire o acesso ao painel antes de bloquear." });
    }

    // ban_duration longa = bloqueado; "none" = liberado. Não apaga nada.
    const { error } = await service.auth.admin.updateUserById(user_id, {
      ban_duration: bloquear ? "876000h" : "none",
    });
    if (error) { console.error(error); return json(400, { erro: "Não foi possível alterar o bloqueio. Tente de novo." }); }
    // Bloqueou: derruba as sessões abertas do aluno (o token de acesso valeria por até 1 h) e registra na auditoria
    if (bloquear) await service.auth.admin.signOut(user_id, "global").catch(() => {});
    const { data: alvo } = await service.from("perfis").select("nome").eq("user_id", user_id).maybeSingle();
    await service.from("auditoria").insert({
      user_id: user.id, origem: "painel", acao: bloquear ? "bloqueio_conta" : "desbloqueio_conta", tabela: "alunos", registro: user_id,
      resumo: (bloquear ? "Bloqueou a conta de " : "Liberou a conta de ") + (alvo?.nome ?? user_id),
    }).then(({ error: e }) => { if (e) console.error(e); });
    return json(200, { ok: true });
  } catch (e) {
    console.error(e);
    return json(500, { erro: "Erro inesperado no servidor." });
  }
});
