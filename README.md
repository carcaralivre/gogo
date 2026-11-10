# GoGo

Launcher nativo de menu bar para macOS. Fica como um ícone `>>` na barra superior.

- **Clique esquerdo** no ícone (ou **⌃⌥⌘G**): abre todos os apps marcados que ainda não estão rodando.
- **Clique direito**: painel com busca, a lista dos apps **marcados** e uma seção **Não marcados** colapsada. Clicar num app só alterna o check; o painel fica aberto até você clicar fora ou apertar Esc.
- Na primeira execução nada vem marcado (use o menu para escolher, ou **Marcar todos**). Daí em diante, apps novos instalados em `/Applications` ou `~/Applications` entram na lista já marcados.
- Opção **Iniciar com o macOS** no menu.
- URL scheme: `open gogo://launch` dispara o mesmo que o clique esquerdo; `open gogo://menu` abre/fecha o painel (bom para Atalhos, Raycast, scripts).

Fontes de apps: `/Applications`, `~/Applications` e `/System/Applications` (inclusive subpastas como `Utilities`).

## Build

Requer Xcode (Swift 6). Não precisa de projeto Xcode; é um Swift Package.

```bash
make install   # compila, gera o ícone, monta GoGo.app, instala em /Applications e abre
```

Outros alvos: `make app` (só monta `build/GoGo.app`), `make run` (roda de `build/`), `make icon` (regenera `Resources/AppIcon.icns`), `make dist` (DMG e zip para distribuir), `make clean`.

## Instalar em outro Mac

Baixe o DMG mais recente em [Releases](https://github.com/carcaralivre/GoGo/releases), ou gere você mesmo:

```bash
make dist
```

Isso gera `dist/GoGo-<versão>.dmg` e `dist/GoGo-<versão>.zip` com binário universal (Apple Silicon e Intel). No outro Mac:

1. Abra o DMG e arraste **GoGo** para **Aplicativos**.
2. Na primeira abertura o macOS vai bloquear, porque o app é assinado só localmente (sem conta Apple Developer paga não há notarização). Libere de um destes jeitos:
   - **Ajustes do Sistema → Privacidade e Segurança**, role até o aviso sobre o GoGo e clique em **Abrir Mesmo Assim**; ou
   - no Terminal: `xattr -dr com.apple.quarantine /Applications/GoGo.app` e abra normalmente.
3. Opcional: no painel do GoGo, engrenagem → **Iniciar com o macOS**.

Isso só é preciso uma vez por Mac. Alternativa, se o outro Mac tiver Xcode: clone o projeto e rode `make install`.

Estado (apps desmarcados) fica em `~/Library/Application Support/GoGo/state.json`.
