# Findout Jornada

Módulo gamificado de estudo para o ENEM, no estilo Duolingo: trilhas por matéria, lições com 5 tipos de exercício, corações, XP, moedas, ofensiva, missões, liga semanal e loja.

## Estrutura

| Pasta | O que é | Vai para o ar como |
|---|---|---|
| `app/` | App do aluno (PWA, celular e desktop) | projeto Vercel com Root Directory `app` |
| `painel/` | Painel de gestão (trilhas, questões, missões, economia, publicação) | projeto Vercel com Root Directory `painel` |
| `supabase/migrations/` | Esquema do banco, segurança (RLS) e funções, em ordem numérica | rodar no SQL Editor do Supabase |
| `conteudo/` | Rascunhos de questões e árvore das matérias | importado pelo painel |

Sem etapa de build: os dois sites são HTML + JS puros e carregam o cliente do Supabase por CDN. Para rodar localmente basta abrir `app/index.html` ou `painel/index.html` num servidor estático qualquer (por exemplo a extensão Live Server do VS Code).

## Configuração

As chaves públicas ficam em `app/config.js` e `painel/config.js`:

```js
window.FJ_CONFIG = { supabaseUrl: 'https://xxxx.supabase.co', supabaseAnonKey: 'eyJ...' };
```

A anon key é pública por design; quem protege os dados é o RLS no banco. A `service_role` key nunca entra neste repositório.

## Publicar

- **Código:** `git push` na `main` (ou Commit + Push no GitHub Desktop). A Vercel publica em 1 a 2 minutos.
- **Conteúdo:** no painel, botão **Publicar**. O app baixa a versão nova na próxima abertura.

Plano de trabalho semana a semana: [PLANO.md](PLANO.md). O que ficou para depois do lançamento: [DEPOIS.md](DEPOIS.md).
