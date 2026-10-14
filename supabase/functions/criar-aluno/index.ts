// =====================================================================
// Findout Jornada · Edge Function "criar-aluno"
// Cria uma conta de aluno já confirmada (sem gastar e-mail), a pedido
// de um administrador logado no painel. A chave service_role fica só
// aqui no servidor — nunca no painel.
//
// Como publicar: Supabase → Edge Functions → Deploy a new function →
// nome "criar-aluno" → colar este arquivo → Deploy ("Verify JWT" ligado).
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
    if (!adm) return json(403, { erro: "Só administradores podem criar contas." });

    const { nome, email, senha } = await req.json().catch(() => ({}));
    if (!nome?.trim()) return json(400, { erro: "Informe o nome do aluno." });
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(String(email ?? "").trim())) return json(400, { erro: "E-mail inválido." });
    if (!senha || String(senha).length < 8) return json(400, { erro: "A senha precisa de pelo menos 8 caracteres." });

    // email_confirm: a conta nasce confirmada e nenhum e-mail é enviado.
    // O gatilho novo_usuario cria perfil e economia com o nome do metadata.
    const { data, error } = await service.auth.admin.createUser({
      email: String(email).trim().toLowerCase(),
      password: String(senha),
      email_confirm: true,
      user_metadata: { nome: String(nome).trim().slice(0, 30) },
    });
    if (error) {
      const msg = /already|registered|exists/i.test(error.message)
        ? "Já existe uma conta com esse e-mail."
        : error.message;
      return json(400, { erro: msg });
    }
    return json(200, { ok: true, user_id: data.user.id });
  } catch (e) {
    return json(500, { erro: "Erro inesperado: " + String(e) });
  }
});
