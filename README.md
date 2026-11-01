# MaxChess

Free online chess: play a friend or a beginner computer, solve puzzles, learn the basics, analyze positions, and play online with an account.

**Play it:** https://themaxchessss.github.io/

## How it works
- `index.html` is the whole site (plain HTML, CSS and JavaScript, using chess.js for the rules).
- Accounts, online games, friends and tournaments run on Supabase. Server-side logic lives in `supabase/functions/` and the database rules in `supabase/migrations/`.
- Pushing to `main` deploys the site with GitHub Pages (`.github/workflows/pages.yml`).
