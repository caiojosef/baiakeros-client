# Raridades e atributos — Baiakeros Tibia nativo / OTC

Atualizado em 05/11/2026: regra de atributos v2. Exclusivo do servidor Canary e OTC nativo; nao pertence ao Idler/mobile. O Quente nao e alterado por esta implementacao local.

## Raridades e loot

| Raridade exibida | Cor | Atributos | Chance apos o equipamento cair |
|---|---|---:|---:|
| Common | Azul | 1 | 40% |
| Rare | Roxo | 2 | 30% |
| Epic | Amarelo | 3 | 20% |
| Ultra | Vermelho | 4 | 10% |

O monstro/boss sorteia seu loot normal. Equipamento elegivel novo que cair recebe exatamente uma raridade; nao ha resultado normal sem raridade. Bonus VIP, loot rate e contribuicao continuam afetando a queda normal, sem multiplicar a raridade novamente. As chances sao altas para testes locais.

Elegiveis: helmet, armor, legs, boots, shield, sword/axe/club, distance, wraps de monk, wand/rod e quiver. Quiver preserva suas regras de municao e capacidade. Excluir rings, amulets, backpacks, demais containers, municoes, runas, exercises/training weapons, moedas, consumiveis e produtos de criatura. Loja/NPC/comando/quest nao reclassificam automaticamente os itens.

Atributos seguem o equipamento e suas restricoes, nao a vocacao de quem matou. Requisitos originais de vocacao, level e elemento continuam valendo. O primeiro atributo e basico; demais atributos sao sorteados sem repeticao no mesmo grupo.

## Grupos de bonus

Os nomes abaixo sao os textos efetivamente exibidos no jogo, em ingles.

| Equipamento | Bonus basico | Bonus adicionais possiveis |
|---|---|---|
| Rod / wand | Magic Level | Maximum Mana; Offensive Rune Cooldown Reduction; Offensive Spell Cooldown Reduction |
| Helmet exclusivo de mage | Magic Level | Maximum Mana; Maximum Health; Armor |
| Armor / legs exclusivos de mage | Armor | Magic Level; Maximum Mana; Maximum Health |
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
| Attack Speed / Offensive Cooldown Reduction | Nao aparece no bonus basico Common | +0,50% a +1,00% | +1,00% a +1,50% | +1,50% a +2,00% |

Attack e aplicado e exibido em pontos inteiros reais, depois de arredondar para baixo. Vida e mana recebem +5 por banda em ambos os extremos do intervalo. Percentuais recebem +0,10 ponto percentual por banda. Armor, Defense e Movement Speed recebem +1 em bandas 2 e 3. Em Epic/Ultra de banda 2 ou 3, skill/magic level usa o extremo superior (Epic +2; Ultra +3). Os bonus so sao considerados quando o atributo faz parte do grupo e foi sorteado.

Exemplo valido de Rare rod de nivel baixo:

> Rare: +1 Magic Level; +17 Maximum Mana.

Exemplo de Epic wand de nivel 150:

> Epic: +2 Magic Level; +40 Maximum Mana; +1.20% Offensive Spell Cooldown Reduction.

Exemplo de Ultra rod de nivel 300+ (quatro atributos):

> Ultra: +3 Magic Level; +70 Maximum Mana; +2.00% Offensive Rune Cooldown Reduction; +1.90% Offensive Spell Cooldown Reduction.

## Cooldowns e velocidade no Canary

Percentuais sao armazenados em basis points inteiros (100 = 1%). O servidor agrega somente equipamentos nos slots de combate, nao itens guardados em backpack/depot. Caps totais de raridade: 3% Attack Speed; 5% reducao de cooldown ofensivo de runas; 5% reducao de cooldown ofensivo de instant spells.

Rune e instant spell sao distinguidos pelo proprio motor. A reducao e aplicada a cooldown individual e ao grupo principal Attack no caminho nativo de lancamento. Nao cancela condicoes de cooldown ja existentes, nao permite usar uma runa durante bloqueio e nao remove os limites de movimento/uso de itens. Cura, suporte e grupos secundarios continuam com suas regras normais.

Os modificadores de Wheel, proficiency e VIP sao calculados antes da reducao de raridade. Preservar o piso de 50% do cooldown individual base apos a taxa nativa. O grupo Attack e o ataque basico nao sao reduzidos abaixo de 1000 ms por raridade; se a regra nativa ja for menor, raridade nao reduz esse intervalo. Nenhum percentual novo e aplicado a cura ou suporte.

Exemplo: 2.000 ms com 1% vira 1.980 ms; com 2,30% vira 1.954 ms. Uma spell de 6.000 ms com 2,30% vira 5.862 ms, desde que o piso nativo permita. Nao confundir percentual de reducao de intervalo com o mesmo aumento percentual exato de DPS.

## Itens existentes e texto em ingles

Nome de item: [Common], [Rare], [Epic] ou [Ultra] antes do nome original. Descricao: Common/Rare/Epic/Ultra: seguido dos atributos em ingles. Tooltip do OTC tambem e ingles.

Itens da versao 1 mantem todos os numeros sorteados, mesmo quando um atributo antigo ja nao faz parte do grupo novo. Ao usar Look/Look in Trade, o servidor converte apenas nome e descricao para ingles. Nao aumenta atributos, nao troca Shielding antigo por outro bonus e nao rerrola. O detalhe original do item e preservado antes da linha de raridade. A traducao e idempotente.

## Persistencia, visual e economia

Salvar raridade, versao da regra, perfil, banda de nivel, origem e atributos na instancia. O resultado e gerado com a criacao do loot/reward, antes de retirar. Transferir, equipar ou relogar nao sorteia novamente. Equipar aplica bonus reais e desequipar os remove, inclusive para equipamentos sem MoveEvent e quivers.

OTC recebe a raridade real por instancia, independente do preco medio. Exibe fundo e borda azul/roxa/amarela/vermelha e limpa a cor ao trocar/esvaziar o slot. Negociacao bkrarity1/recurso 136 mantem o pacote anterior para clientes antigos.

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

Testes v2: 192 combinacoes de grupos/ranks/bandas; intervalos crescentes; grupos de mage e armas fisicas; quiver; loot normal/boss/nested; traducao exata do exemplo Rare sem mudar numeros; idempotencia; 100 mil sorteios. Teste C++ cobre reducoes reais em milissegundos, teto de 5%, pisos, valores negativos/corrompidos e intervalos pequenos.

Compilacao release do servidor v2 concluida. Validacao nativa com personagem descartavel confirmou equip/de-equip de boots, quiver e wand, aplicacao e remocao de vida/mana/skills/magic level/movement speed, descricao em ingles e preservacao exata dos atributos em dois logins reais com save/load no banco. OTC confirmou o recurso 136 e a instancia Ultra recebida. A conta, personagem, equipamentos e credenciais temporarios foram removidos.

Cooldowns foram verificados por testes C++ de calculo e integracao no caminho nativo; medicao de casts em combate e balanceamento de gameplay/mercados ainda precisam de testes antes de publicar no Quente.

Reproduzir testes de regras a partir da raiz do servidor: luajit tests/lua/item_rarity_spec.lua. Teste C++ independente: g++ -std=c++20 -Isrc tests/unit/utils/rarity_balance_standalone.cpp -o /tmp/rarity-balance-test && /tmp/rarity-balance-test. Nao compilar esse teste com -DNDEBUG, pois usa assert.

Testes adicionais de /i: sintaxe antiga e nova, combinacao Forge/raridade, lote por instancia, nomes/aliases, random, rejeicao sem criar item, falha de rolagem sem entregar item normal e preservacao do Mini Obelisk. API valida ranks administrativos e impede rerrolar itens existentes; 192 combinacoes e 100 mil sorteios de loot continuam passando.
