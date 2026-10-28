# Trabalhar no cliente Baiakeros em equipe

Este repositorio privado e a fonte compartilhada do OTC nativo. O launcher e o servidor sao projetos separados. Cada pessoa usa a propria conta GitHub, aceita o convite de colaborador e instala o Git para Windows. Nao e preciso criar um fork quando se tem acesso de escrita neste repositorio.

## Primeira copia

No PowerShell, escolha uma pasta de desenvolvimento e execute:

```powershell
git clone https://github.com/caiojosef/baiakeros-client.git
cd baiakeros-client
git switch main
git pull --ff-only origin main
```

Autentique no GitHub pelo navegador quando o Git solicitar. Nunca coloque senha ou token na URL. Configure sua identidade uma vez, usando o email da sua conta ou seu email noreply do GitHub:

```powershell
git config user.name "Seu Nome"
git config user.email "seu-email-do-github"
```

## Configuracao individual

Quem tem servidor local usa:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\prepare-development.ps1
```

Quem vai testar no servidor publico usa, na primeira configuracao:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\prepare-development.ps1 -Environment Production
```

O comando cria environment.lua e config.ini somente quando nao existem. Os arquivos ficam fora do Git. Rodar novamente preserva os ajustes da maquina; para mudar de perfil depois, edite environment.lua ou salve uma copia e remova apenas esse arquivo antes de repetir o comando. O perfil Development usa localhost; Production usa baiakeros.com. Nunca mude o environment.development.lua compartilhado para o endereco pessoal de uma maquina.

Clonar baixa fontes e os recursos versionados, mas nao instala compilador, executavel nem todos os arquivos grandes de things/sounds. Para comecar a editar Lua e interface, atualize o jogo com o launcher oficial e copie do cliente atualizado:

- otclient.exe para a raiz desta copia do repositorio;
- data/things/1525/ para data/things/1525/;
- data/sounds/1525/ para data/sounds/1525/ quando disponivel.

O cliente instalado pelo launcher normalmente fica em %APPDATA%\BaiakerosLauncher. Copie somente esses recursos, sem credenciais, configuracoes de conta ou pastas de perfil. Execute .\otclient.exe a partir da raiz do repositorio. Lua, OTUI e imagens usam os arquivos desta copia; alteracoes de C++ exigem recompilacao.

Para compilar C++ no Windows, siga [o guia de compilacao](building/windows-(cmake).md), usando este repositorio Baiakeros no lugar do repositorio upstream do exemplo. O preset atual usa Visual Studio 2026, MSVC v145, Windows SDK, ferramentas CMake/Ninja, pacote de idioma ingles e vcpkg. No Developer PowerShell x64, configure VCPKG_ROOT para sua instalacao e execute:

```powershell
$env:VCPKG_ROOT = 'C:\caminho\para\vcpkg'
cmake --preset windows-release -DTOGGLE_BIN_FOLDER=ON -DCMAKE_BUILD_TYPE=Release
cmake --build --preset windows-release --parallel 4
.\build\windows-release\bin\otclient.exe
```

Cada pessoa escolhe seus caminhos. Nao e necessario ter disco G: nem copiar a WSL do Caio. Para testar localhost, e necessario ter um servidor local; para testar o Quente, use o perfil Production e sua conta de teste.

## Cada alteracao em sua branch

Antes de iniciar, salve seu trabalho atual em um commit. Parta de main atualizada:

```powershell
git switch main
git pull --ff-only origin main
git switch -c seu-usuario/ajuste-interface
# editar e testar
git status --short --branch
git diff
git add modules/caminho/do/arquivo.lua
git commit -m "fix(login): describe the change"
git push -u origin seu-usuario/ajuste-interface
```

Troque o caminho pelo arquivo realmente alterado; adicione explicitamente cada arquivo necessario. Para tarefas feitas pelo agente neste projeto, use o prefixo dudantas/ nas novas branches. Para o colega, use o nome de usuario dele. Nao trabalhem simultaneamente na mesma branch nem enviem mudancas diretamente para main.

No GitHub, abra um Pull Request da sua branch para main. Descreva o resultado, anexe imagens quando a interface mudar e informe como testou. A outra pessoa revisa; depois integrem o PR pela interface do GitHub. Enviar uma branch nao atualiza a main e nao publica o jogo.

Depois da integracao, ambos recebem a versao compartilhada com:

```powershell
git switch main
git pull --ff-only origin main
```

Se a outra pessoa integrou algo enquanto sua tarefa ainda esta em andamento, salve suas alteracoes e atualize sua branch:

```powershell
git fetch origin
git merge origin/main
```

Se houver conflito, revisem os trechos dos dois trabalhos, testem e facam o commit da resolucao antes de enviar novamente. Nao usem push --force para apagar o trabalho do colega. Se git pull --ff-only recusar, investiguem a divergencia antes de continuar.

## Publicacao

O fluxo e: branch -> testes -> Pull Request -> main -> pacote de producao -> publicacao explicitamente autorizada. O pacote usa environment.production.lua sem substituir o environment.lua local. Os manifestos client e assets devem ter a mesma revisao e os novos caminhos de pacotes precisam estar liberados na lista do nginx.

Nunca envie banco de dados, credenciais, chaves SSH, tokens ou perfis de jogadores ao repositorio. Executaveis, caches, dependencias e configuracoes individuais ficam fora dos commits. Se os checks do GitHub Actions nao executarem por cobranca/limite da conta, registrem a limitacao e os testes locais; nao tratem checks nao executados como aprovados.
