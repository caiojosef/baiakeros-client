# Raridades e atributos — Baiakeros Tibia nativo / OTC

Atualizado em 05/11/2026: regra de atributos v3 (Attack Speed e runas ofensivas ate 25%, piso de 1500 ms). Exclusivo do servidor Canary e OTC nativo; nao pertence ao Idler/mobile. Publicado no Quente por solicitacao explicita em 05/11/2026, junto com o cliente nativo r42.

## Raridades e loot

| Raridade exibida | Cor | Atributos | Chance apos o equipamento cair |
|---|---|---:|---:|
| Common | Azul | 1 | 85% |
| Rare | Roxo | 2 | 10% |
| Epic | Amarelo | 3 | 4% |
| Ultra | Vermelho | 4 | 1% |

O monstro/boss sorteia seu loot normal. Equipamento elegivel novo que cair recebe exatamente uma raridade; nao ha resultado normal sem raridade. Bonus VIP, loot rate e contribuicao continuam afetando a queda normal, sem multiplicar a raridade novamente. Distribuicao aprovada para publicacao em 05/11/2026: 85% Common, 10% Rare, 4% Epic e 1% Ultra. Continua sem equipamento elegivel normal apos cair.

Elegiveis: helmet, armor, legs, boots, shield, sword/axe/club, distance, wraps de monk, wand/rod e quiver. Quiver preserva suas regras de municao e capacidade. Excluir rings, amulets, backpacks, demais containers, municoes, runas, exercises/training weapons, moedas, consumiveis e produtos de criatura. Loja/NPC/comando/quest nao reclassificam automaticamente os itens. Excecao de loot de bosses: Bag You Desire, Primal Bag e Bag You Covet aplicam a raridade ao equipamento entregue ao abrir a bolsa, antes de enviar sua instancia ao cliente. Arcane Bag mantem o fluxo proprio sem reclassificacao.

Atributos seguem o equipamento e suas restricoes, nao a vocacao de quem matou. Requisitos originais de vocacao, level e elemento continuam valendo. O primeiro atributo e basico; demais atributos sao sorteados sem repeticao no mesmo grupo.

## Grupos de bonus

Os nomes abaixo sao os textos efetivamente exibidos no jogo, em ingles.

| Equipamento | Bonus basico | Bonus adicionais possiveis |
|---|---|---|
| Rod / wand | Magic Level | Maximum Mana; Offensive Rune Cooldown Reduction; Offensive Spell Cooldown Reduction |
| Helmet exclusivo de mage | Magic Level | Maximum Mana; Maximum Health; Armor; Offensive Rune Cooldown Reduction |
| Armor / legs exclusivos de mage | Armor | Magic Level; Maximum Mana; Maximum Health; Offensive Rune Cooldown Reduction |
| Sword / axe / club | Attack | Sword/Axe/Club Fighting correspondente; Attack Speed; Maximum Health; Maximum Mana |
| Bow / crossbow / distance | Attack | Distance Fighting; Attack Speed; Maximum Health; Maximum Mana |
| Wraps de monk | Attack | Fist Fighting; Attack Speed; Maximum Health; Maximum Mana |
| Quiver | Distance Fighting | Maximum Mana; Maximum Health; Attack Speed |
| Shield | Defense | Shielding; Maximum Health; Armor |
| Boots | Movement Speed | Maximum Health; Maximum Mana; Armor |
| Armor / helmet / legs exclusivos de paladin | Armor | Distance Fighting; Maximum Health; Maximum Mana |
| Armor / helmet / legs exclusivos de monk | Armor | Fist Fighting; Maximum Health; Maximum Mana |
| Armor / helmet / legs genericos, de knight ou com restricoes compartilhadas | Armor | Maximum Health; Maximum Mana; Shielding |

Rods/wands novos nao sorteiam Shielding ou atributos fisicos. Armas fisicas nao sorteiam Magic Level nem reducao de cooldown de runa. Equipamento compartilhado entre vocacoes nao e classificado automaticamente como equipamento de mage apenas por listar sorcerer/druid entre varias vocacoes.

## Progressao por raridade e nivel minimo do equipamento

Bandas de nivel minimo de uso: 0–49 (banda 0), 50–149 (1), 150–299 (2), 300+ (3). Isso e separado de forge tier, nivel do personagem e quantidade de atributos. Nunca alterar level minimo do item para aplicar raridade.

| Atributo, antes do ajuste por nivel | Common | Rare | Epic | Ultra |
|---|---:|---:|---:|---:|
| Magic Level / Fighting / Shielding | +1 | +1 | +1 a +2 | +2 a +3 |
| Maximum Health | +5 a +10 | +10 a +20 | +15 a +30 | +25 a +40 |
| Maximum Mana | +10 a +15 | +15 a +25 | +25 a +40 | +40 a +60 |
| Armor / Defense | +1 | +1 a +2 | +2 a +3 | +3 a +4 |
| Movement Speed | +1 a +2 | +2 a +3 | +3 a +4 | +4 a +5 |
| Attack | 1–2% do ataque base, minimo +1 | 2–3%, minimo +1 | 3–4%, minimo +1 | 4–5%, minimo +1 |
| Attack Speed / Offensive Rune Cooldown Reduction | Nao aparece no bonus basico Common | +3,00% a +6,00% | +6,00% a +9,00% | +9,00% a +12,00% |
| Offensive Spell Cooldown Reduction | Nao aparece no bonus basico Common | +0,50% a +1,00% | +1,00% a +1,50% | +1,50% a +2,00% |

Attack e aplicado e exibido em pontos inteiros reais, depois de arredondar para baixo. Vida e mana recebem +5 por banda em ambos os extremos do intervalo. Attack Speed e Offensive Rune Cooldown Reduction recebem +0,60 ponto percentual por banda; Offensive Spell Cooldown Reduction recebe +0,10 ponto percentual por banda. Assim, Ultra de level 300+ sorteia +10,80% a +13,80% para ataque/runa. Armor, Defense e Movement Speed recebem +1 em bandas 2 e 3. Em Epic/Ultra de banda 2 ou 3, skill/magic level usa o extremo superior (Epic +2; Ultra +3). Os bonus so sao considerados quando o atributo faz parte do grupo e foi sorteado.

Exemplo valido de Rare rod de nivel baixo:

> Rare: +1 Magic Level; +17 Maximum Mana.

Exemplo de Epic wand de nivel 150:

> Epic: +2 Magic Level; +40 Maximum Mana; +1.20% Offensive Spell Cooldown Reduction.

Exemplo de Ultra rod de nivel 300+ (quatro atributos):

> Ultra: +3 Magic Level; +70 Maximum Mana; +12.00% Offensive Rune Cooldown Reduction; +1.90% Offensive Spell Cooldown Reduction.

## Cooldowns e velocidade no Canary

Percentuais sao armazenados em basis points inteiros (100 = 1%). O servidor agrega somente equipamentos nos slots de combate, nao itens guardados em backpack/depot. Caps totais separados de raridade: 25% Attack Speed; 25% reducao de cooldown ofensivo de runas; 5% reducao de cooldown ofensivo de instant spells. Nao somar ataque automatico com cooldown de runa: cada um usa seu proprio conjunto de bonus.

Rune e instant spell sao distinguidos pelo proprio motor. A reducao e aplicada a cooldown individual e ao grupo principal Attack no caminho nativo de lancamento. Nao cancela condicoes de cooldown ja existentes, nao permite usar uma runa durante bloqueio e nao remove os limites de movimento/uso de itens. Cura, suporte e grupos secundarios continuam com suas regras normais.

Os modificadores de Wheel, proficiency e VIP sao calculados antes da reducao de raridade. Preservar o piso de 50% do cooldown individual base apos a taxa nativa. Ataque basico e cooldown individual/grupo Attack de runas ofensivas nao sao reduzidos abaixo de 1500 ms por raridade. Instant spells mantem o piso anterior do grupo Attack de 1000 ms. Se a regra nativa ja for menor que um piso, raridade nao reduz nem aumenta esse intervalo. Nenhum percentual novo e aplicado a cura ou suporte.

Exemplos para ataque/runa de 2.000 ms: 10% -> 1.800 ms; 20% -> 1.600 ms; 25% ou mais -> 1.500 ms. Uma runa de cooldown individual de 6.000 ms com 25% ainda tem 4.500 ms; o piso de 1.500 ms nao transforma todas as runas em um cooldown fixo. A spell instantanea de 6.000 ms com 2,30% continua em 5.862 ms, desde que o piso nativo permita. Nao confundir percentual de reducao de intervalo com o mesmo aumento percentual exato de DPS.

## Itens existentes e texto em ingles

Nome de item: [Common], [Rare], [Epic] ou [Ultra] antes do nome original. Descricao: Common/Rare/Epic/Ultra: seguido dos atributos em ingles. Tooltip do OTC tambem e ingles.

Itens antigos preservam todos os outros numeros e a selecao de atributos. A v3 atualiza somente Attack Speed e Offensive Rune Cooldown Reduction pre-v3 multiplicando por seis o roll original (limitado ao maximo anterior de 2,30%), sem sortear novamente. Marcadores independentes impedem multiplicacao repetida; a versao original do loot e mantida. Equipamento equipado e atualizado no login; outras instancias sao atualizadas por Look/Look in Trade. O calculo C++ ja interpreta o bonus antigo corretamente antes da migracao do texto. A descricao fica em ingles e preserva o detalhe original do item. Nao adiciona atributos que nao existiam, nem troca Shielding por outro bonus.

Exemplo real do usuario: bow +2,11% -> +12,66%; quiver +1,85% -> +11,10%; soma 23,76%, intervalo calculado de 1.524 ms sobre 2.000 ms (arredondamento para baixo). Rolls maiores podem atingir o piso de 1.500 ms. Para somar reducao de runas, novos helmets/armors/legs exclusivos de mage tambem podem sortear esse atributo; a quantidade de atributos continua 1/2/3/4.

## Persistencia, visual e economia

Salvar raridade, versao da regra, perfil, banda de nivel, origem e atributos na instancia. O resultado e gerado com a criacao do loot/reward, antes de retirar. Transferir, equipar ou relogar nao sorteia novamente. Equipar aplica bonus reais e desequipar os remove, inclusive para equipamentos sem MoveEvent e quivers.

OTC recebe a raridade real por instancia, independente do preco medio. Exibe fundo e borda azul/roxa/amarela/vermelha e limpa a cor ao trocar/esvaziar o slot. Negociacao bkrarity1/recurso 136 mantem o pacote anterior para clientes antigos.

O encerramento de drag, drop rejeitado, saida de hover e destruicao da origem arrastada devem restaurar a borda da raridade do item que permanece no slot. Limpar o destaque temporario de drag nao pode apagar a borda persistente. Itens sem raridade e slots vazios continuam limpando a borda temporaria. Testes: `luajit tests/lua/item_rarity_border_spec.lua` e teste nativo `tests/native/item_rarity.lua` com widgets reais.

Rare/Epic/Ultra sao protegidos contra venda NPC em lote ou por ID nesta primeira versao; Common pode ser vendido pelo preco original. O mercado nativo de commodities bloqueia raridades pois recria por tipo. Troca direta e Market real usam a serializacao da instancia. Nao aumentar o pagamento NPC por raridade.

## Criacao administrativa com /i

O comando continua exclusivo de GOD. Sem parametro de raridade, preserva a criacao original e o tier da Forge: `/i item, quantidade, tier`. O parametro de raridade e opcional e usa nomes, sem confundir os numeros da Forge com ranks Common/Rare/Epic/Ultra.

| Exemplo | Resultado |
|---|---|
| `/i 53226` | Stellar Moonsilver Bow original, sem raridade |
| `/i 53226, 1, ultra` | Um bow Ultra com quatro bonus sorteados no grupo de bow |
| `/i 53226, 1, rare` | Um bow Rare com dois bonus sorteados |
| `/i 53226, 5, random` | Cinco bows; raridade e bonus sorteados individualmente |
| `/i 53226, 1, 3, ultra` | Um bow Forge tier 3 e raridade Ultra |
| `/i 39150, 1, epic` | Uma quiver Epic com tres bonus sorteados |

Aceita common, rare, epic, ultra e random; aliases comum, raro, epico/épico e aleatorio/aleatório. A raridade fixa somente o rank: selecao de atributos e valores continuam aleatorios dentro das regras por equipamento/nivel. Atributo basico do grupo continua garantido. Nao altera itens existentes nem chances do loot normal. Rejeita raridades desconhecidas e itens inelegiveis antes de criar qualquer unidade. Cada item do lote recebe sua propria rolagem. Preserva entrega em backpacks/containers, fallback no chao, stacks, cargas, fluidos, tier da Forge e o atalho Mini Obelisk.

## Testes e fontes

Fonte local: WSL Ubuntu-24.04, /home/baiakeros/baiakeros. OTC: G:\otserv\otclient-main. Branches: dudantas/item-rarity-20261105. Preservar localhost, start.sh e recompile.sh. Publicacao no Quente precisa de solicitacao explicita.

Testes de regras e regressao: 192 combinacoes de grupos/ranks/bandas; intervalos crescentes; grupos de mage e armas fisicas; quiver; loot normal/boss/nested; traducao exata do exemplo Rare sem mudar numeros; idempotencia; 100 mil sorteios. Teste C++ cobre reducoes reais em milissegundos, tetos separados de 25% para ataque/runa e 5% para instant spells, pisos, valores negativos/corrompidos e intervalos pequenos.

Compilacao release do servidor v2 concluida. Validacao nativa com personagem descartavel confirmou equip/de-equip de boots, quiver e wand, aplicacao e remocao de vida/mana/skills/magic level/movement speed, descricao em ingles e preservacao exata dos atributos em dois logins reais com save/load no banco. OTC confirmou o recurso 136 e a instancia Ultra recebida. A conta, personagem, equipamentos e credenciais temporarios foram removidos.

Cooldowns foram verificados por testes C++ de calculo e integracao no caminho nativo; medicao de casts em combate e balanceamento de gameplay/mercados continuam sujeitos a avaliacao de gameplay apos esta publicacao autorizada.

Reproduzir testes de regras a partir da raiz do servidor: luajit tests/lua/item_rarity_spec.lua. Teste C++ independente: g++ -std=c++20 -Isrc tests/unit/utils/rarity_balance_standalone.cpp -o /tmp/rarity-balance-test && /tmp/rarity-balance-test. Nao compilar esse teste com -DNDEBUG, pois usa assert.

Testes adicionais de /i: sintaxe antiga e nova, combinacao Forge/raridade, lote por instancia, nomes/aliases, random, rejeicao sem criar item, falha de rolagem sem entregar item normal e preservacao do Mini Obelisk. API valida ranks administrativos e impede rerrolar itens existentes; 192 combinacoes e 100 mil sorteios de loot continuam passando.

Validacao v3: migracao dos rolls reais 2,11%/1,85% e de runa 2,00%, idempotencia, preservacao dos demais atributos, grupos de mage com runa e intervalos C++ ate 1.500 ms. Instant spells preservam o teto de 5%. Compilacao release concluida e v3 ativada localmente em 05/11/2026, com zero jogadores conectados no reinicio. Teste nativo de startup passou: instancias reais de bow/quiver/rod, migracao uma unica vez, preservacao dos outros atributos, serialize/clone e faixas de rolls novas. Os itens temporarios foram removidos e o teste deixou de ser carregado no startup. Servidor online em 7171/7172; ainda e necessario avaliar o balanceamento em combate. A publicacao no Quente foi concluida posteriormente nesta mesma data, conforme o registro abaixo.

## Publicacao no Quente e GitHub em 05/11/2026

Servidor publicado e reiniciado com sucesso, fonte de runtime d2312a552ab8698cb37b49373e1629d4cad60b98, SHA-256 do executavel nativo e9ab25412e552e7dc0a6663bb392ca4dcf1bf4708d448d97e82c7a3ae5380075. Compilado no proprio Ubuntu do Quente, sem copiar binario da WSL. Portas 7171/7172 abertas e nenhuma mensagem de erro no log de inicializacao verificado. O servidor continua gerenciado pelo servico canary existente.

Cliente e assets publicados juntos na revisao 42, fonte c392611e501981dab03431d94108dec8a9213073. Foram preservados 16.332 arquivos do manifesto e publicados 13 pacotes alterados, sem exclusoes. Todos os pacotes novos tiveram tamanho, hash compactado e hash descompactado verificados por HTTPS publico. O teste real TestPublishedNativePackages do launcher passou, incluindo caminho com caractere #. Os jogadores devem fechar o OTC e abri-lo pelo launcher para receber a revisao 42.

start.sh, recompile.sh, config.lua e market.local.lua tiveram seus hashes preservados. Configuracao localhost local preservada. Banco e mapas de jogadores nao foram substituidos. Alteracoes de codigo que ja estavam no Quente foram revisadas e preservadas no Git: validacao de sessao de dois fatores, acesso de contas staff durante manutencao e coleta de powergamers. Backup de codigo, manifests e configuracao nginx em /var/backups/baiakeros/rarity-r42-20261105; patch de codigo anterior tambem preservado em stash.

Branches de trabalho enviadas para origin/dudantas/item-rarity-20261105 nos dois repositorios. PRs: https://github.com/caiojosef/baiakeros/pull/16 e https://github.com/caiojosef/baiakeros-client/pull/20. Nenhum merge na main foi realizado. PRs anteriores #14/#15 do servidor e #19 do cliente tem sobreposicao de historico com estas branches.

Auditoria final: nenhum commit da main remota estava faltando nas duas copies locais. Nenhuma outra branch do servidor tinha commits ausentes. No cliente, attack-controls-layout e node-stand-route possuem patches equivalentes ja incorporados; parte de paladin-helper-1525 tambem. Seu commit historico cbdd31a contem alternativas antigas de efeitos de ataque e Alt-Tab/fullscreen que nao foram reaplicadas automaticamente. chore/update-vcpkg-baseline tem dois commits automaticos de dependencia pendentes, mantidos separados desta publicacao. Esses casos sao pendencias de revisao, nao atualizacoes novas do colaborador na main.

Validacao adicional: 334 arquivos Lua da publicacao integrada passaram no parser LuaJIT; testes de Warzones, manutencao, /i, bolsas de boss e Arcane Bag passaram localmente e no Quente. As bolsas rolam antes da entrega; falta de espaco ou falha de criacao/rolagem preserva a bolsa e remove a instancia temporaria.
