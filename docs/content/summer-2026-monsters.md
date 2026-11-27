# Criaturas 15.30 adaptadas ao Baiakeros 15.25

Instalação local em 26/11/2026. Servidor WSL e cliente local continuam no protocolo 15.25.

Foram acrescentados 50 cadastros de criaturas e o ataque `phosphorus curse`.
Os 44 nomes de monstros existentes nos spawns dos dez recortes baixados estão
cobertos pelos cadastros antigos ou novos. Nenhum mapa ou spawn ativo foi editado.

Recursos acrescentados: 1.217 objetos, 29 outfits, 1 efeito e 12 projéteis, com
185 metadados de itens e 187 folhas de sprites. Os sprites novos receberam um
deslocamento de 301.975 IDs, preservando os IDs e definições antigos integralmente.
Foram adicionadas 21 entradas de bestiário e 8 de bosses no staticdata do cliente,
adaptando o campo de bosses do formato oficial ao esquema do OTC.
A proficiência 474 foi acrescentada a servidor e cliente, preservando as 442 antigas.

## Origem

Monstros e itens: https://github.com/zimbadev/crystalserver
Commit: 44ad77dabeb256ee139b25837858ec9ae8ec921d
Diretório original: data-global/monster/summer_update_2026
Licença original GPLv2: docs/third-party/crystalserver-GPL-2.0.txt

Recursos gráficos: https://github.com/zimbadev/gameclient/releases/tag/15.30.004fb1
Commit: a4fdab6f8cccb91c9124be541d2db977118b6587

## Escopo das salas

Estes são os cadastros e recursos para colocar as criaturas nos mapas gradualmente.
Não foram instaladas as quests, alavancas, entradas, recompensas, dificuldade dinâmica
ou transições de fase das novas arenas. A fonte usa valores provisórios para alguns
danos, defesas e HP de bosses; não representa reprodução completa do Global.
The Moonsnow Magnolia foi mantida como criatura independente: removidas apenas
as referências aos três eventos de arena ainda não instalados. Seu combate básico,
loot e summons continuam cadastrados. As formas finais dos demais bosses podem
ser invocadas separadamente, mas não alternam automaticamente sem o script da sala.
Os demais auxiliares de quest (por exemplo Energy Cannon) têm o cadastro, mas a
interação da quest deve ser ligada junto com o respectivo mapa.

## Validação

- Sintaxe dos 50 arquivos e ataque especial: aprovada.
- Cadastros, summons e ataques externos: resolvidos.
- 89 etapas de decomposição e 143 IDs distintos de loot: resolvidos.
- 187 folhas de sprites: descomprimidas e dimensões validadas.
- OTC nativo: catálogo carregado, 50 criaturas renderizadas, 26 itens verificados,
  sem erros ou avisos no perfil descartável de teste.
- Servidor WSL reiniciado vazio e online, mantendo manutenção habilitada.
- Regressão BossCustomDrops: 43 verificações aprovadas.
- Appearance antigo e configurações preservados; mapa principal com SHA-256
  d6c812adafed6105653d6f466170e84712b2dce09dadbde298db1e8a601c2ee4.

## Cliente e Remeres

Cliente local: G:/otserv/otclient-main/data/things/1525.
O executável não precisou ser recompilado. Minimap e perfil pessoal não foram alterados.
No Remeres, o diretório de monstros Lua deve apontar para a pasta completa:
\\wsl.localhost\Ubuntu-24.04\home\baiakeros\baiakeros\data-otservbr-global\monster
Recarregue os dados ou reabra o editor após salvar seu trabalho para atualizar
os cadastros em memória. Os assets 15.30 do editor continuam no pacote separado.
Não troque os assets adaptados do OTC por uma cópia completa do cliente oficial.

Os assets binários de data/things/1525 são em grande parte ignorados pelo Git neste
projeto. Uma futura publicação precisa distribuir os arquivos ativos referenciados
no catalog-content.json e atualizar o pacote público de assets; apenas dar push
no catálogo não entrega as imagens novas. Os arquivos antigos foram mantidos.
Não houve push, publicação ou alteração no Quente nesta tarefa.

## Backup

/home/baiakeros/backups/monsters-1530-20261126-143323

O inventory.json registra os arquivos instalados inicialmente; os arquivos antigos
de proficiência também estão salvos no mesmo backup. Configurações e mapa não
precisam de restauração porque não foram alterados.

## Cadastros

- Maior Domus
- Maior Domus (Final)
- Mimar Haffar
- Mimar Haffar (Final)
- Phosphorus
- Phosphorus (Final)
- Rakesh Moonfang
- The Moonsnow Magnolia
- Cult Initiate
- Devoted Radiant Acolyte
- Devoted Radiant Inquisitor
- Devoted Radiant Paragon
- Devoted Radiant Templar
- Devoted Radiant Warden
- Devoted Radiant Zealot
- Druid Rival
- Elite Fanatic
- Energy Cannon
- Energy Cannon Right
- Furious Jaracal
- Iceplume Strider
- Jaracal
- Knight Rival
- Monk Rival
- Moonsilver Augur
- Moonsilver Custodian
- Moonsilver Guardian
- Moonsilver Protector
- Moonsilver Sentinel
- Moonsilver Storm
- Moonspawn Blightspitter
- Moonspawn Juggernaut
- Moonspawn Oozecrown
- Moonstone Excavator
- Moonstone Miner
- Moonstone Overseer
- Paladin Rival
- Petrified Fanatic
- Radiant Acolyte
- Radiant Inquisitor
- Radiant Paragon
- Radiant Templar
- Radiant Warden
- Radiant Zealot
- Silverfrost Sentinel
- Sorcerer Rival
- Trapped Soul
- True Feverbloom Asura
- True Frostnight Asura
- Winged Jaracal
