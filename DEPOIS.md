# Depois do lançamento

Tudo que ficou fora do escopo de dezembro de 2026. Em janeiro a gente prioriza.

## Abrir o cadastro ao público (checklist do lançamento)

- [ ] Configurar SMTP próprio no Supabase (Brevo grátis: 300 e-mails/dia) e subir os rate limits de e-mail
- [ ] Religar "Allow new users to sign up" (Authentication → Sign In / Up)
- [ ] Traduzir os templates de e-mail do Supabase (confirmação, recuperação de senha)
- [ ] Ligar CAPTCHA (Cloudflare Turnstile) e proteção contra senhas vazadas
- [ ] Filtro de nomes impróprios (aparecem no ranking das ligas)

## Funcionalidades

- [ ] Notificação push (ofensiva prestes a apagar, missões renovadas)
- [ ] Lojas de aplicativo (Capacitor → App Store e Google Play)
- [ ] Cobrança automática do Findout+ (Stripe / Pagar.me / Asaas)
- [ ] Missão em dupla
- [ ] Integração com o login do portal Findout (Laravel)
- [ ] Resoluções em vídeo dos professores (Findout+)
- [ ] Teste para pular seção inteira
- [ ] Mais matérias além das 3 do lançamento
