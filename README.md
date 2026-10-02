# Salesforce — Renov Artisan France

Projet Salesforce (format SFDX) travaillé avec Claude Code et la méthode BMAD.

- `force-app/` — nouveau code (architecture propre)
- `legacy-app/` — ancien code récupéré de l'org
- `CLAUDE.md` — règles suivies par Claude

## Travailler à distance

Ouvrir [claude.ai/code](https://claude.ai/code), choisir ce dépôt, écrire la demande.
Les outils (Salesforce CLI, ESLint, Prettier, Jest, BMAD) s'installent automatiquement au démarrage.

## Commandes utiles

```bash
npm run lint            # vérifie le JavaScript des LWC
npm run prettier        # met en forme Apex, LWC, XML
npm test                # tests Jest des LWC
sf project deploy start # déploie vers l'org connectée
```
