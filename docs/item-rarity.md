# Raridades — Baiakeros Tibia nativo e OTC

Definicao atualizada em 05/11/2026 conforme a conversa com Caio. Exclusivo do servidor Canary de Tibia e do OTC Baiakeros. Nao envolve Idler/mobile.

## Fluxo

Monstro ou boss sorteia seu loot normalmente. Cada equipamento elegivel efetivamente criado recebe uma unica raridade e exatamente o numero de atributos dela. Nao existe resultado normal sem raridade para novos equipamentos elegiveis. A raridade fica na instancia; mover, equipar, trocar ou relogar nao sorteia novamente. Itens existentes nao sao reclassificados.

| Raridade | Cor | Atributos | Chance condicional ao equipamento cair |
|---|---|---:|---:|
| Comum | Azul | 1 | 40% |
| Raro | Roxo | 2 | 30% |
| Epico | Amarelo | 3 | 20% |
| Ultra | Vermelho | 4 | 10% |

Chances altas para teste, apresentadas e confirmadas na conversa junto da escolha de atributos por equipamento. Loot rate, VIP e contribuicao de boss continuam afetando a queda normal; nao multiplicam a raridade novamente. Exemplo: se um Troll soltar leather boots, aquela unidade recebe um dos quatro tipos e seus bonus, sem criar outra bota.

## Elegiveis

Helmet, armor, legs, boots, shield, armas melee/distance, wand/rod e **quiver**. Quiver e a excecao entre containers: preserva capacidade e regras das municoes.

Excluidos: rings, amulets, backpacks, demais containers, municoes, runas, exercises/training weapons, moedas, produtos de criatura, consumiveis e objetos sem funcao de equipamento. Itens de NPC, loja, comandos ou quest nao sao convertidos automaticamente. O filtro opera no loot normal e nas recompensas aleatorias de bosses.

## Atributos definidos pelo equipamento

A vocacao de quem matou nao muda o resultado. Permanecem os requisitos originais de vocacao, level, elemento e uso. O primeiro atributo e basico; os adicionais sao distintos, sorteados no grupo do equipamento.

| Equipamento | Atributo basico | Adicionais possiveis |
|---|---|---|
| Sword/axe/club | Ataque do item | Skill da arma, vida, mana, armadura |
| Distance | Ataque do item | Distance, vida, mana, armadura |
| Wand/rod | Magic level | Mana, vida, shielding |
| Armor restrita a sorcerer/druid | Armadura | Magic level, mana, vida, shielding |
| Armor restrita a paladin | Armadura | Distance, vida, mana, shielding |
| Armor exclusiva de monk | Armadura | Fist fighting, vida, mana, shielding |
| Shield | Defesa | Shielding, vida, mana, armadura |
| Quiver | Distance | Vida, mana, shielding |
| Armor generica ou compartilhada, inclusive knights | Armadura | Vida, mana, shielding |

Valores iniciais por atributo: ataque +1 ate 5% do ataque base, arredondado para baixo com minimo +1; armadura/defesa +1 a +2; vida maxima +10 a +30; mana maxima +15 a +40; skill/shielding/magic level +1. Um Comum tem apenas o basico, Raro tem 2 atributos, Epico 3 e Ultra 4. Armadura generica nao ganha uma skill ofensiva de outra vocacao.

Magic level usa as formulas nativas do Canary. Nao ha bonus novo de velocidade de ataque/runas, cooldown ou amplificacao elemental global nesta primeira versao. Forge tier e imbuements continuam separados. Limites por instancia sao conferidos tambem no C++.

## Persistencia, visual e vendas

Salvar raridade, versao, perfil, origem e bonus na instancia, com nome e descricao legiveis. Aplicar o sorteio ao gerar a recompensa, antes da coleta. Os mesmos dados acompanham corpse, backpack, quiver, loot pouch, reward chest, depot e troca direta quando o motor preserva a instancia.

O OTC recebe raridade real por instancia e mostra fundo/moldura azul, roxo, amarelo ou vermelho; preco medio nao determina essa raridade. Ao esvaziar ou trocar o slot, limpar a cor anterior. Objetos sem raridade conservam a decoracao de preco existente.

Raro/Epico/Ultra ficam protegidos de venda NPC por ID e venda em lote nesta primeira versao, sem opcao de desbloqueio ainda. Comum pode ser vendido pelo preco original. O mercado nativo de commodities fica bloqueado para raridades porque recria itens pelo tipo; o Market real que serializa a instancia e a troca direta devem preservar atributos e precisam de teste de transferencia. Nao aumentar pagamentos NPC por raridade.

## Compatibilidade e ambiente

Novo OTC anuncia bkrarity1 no login. Apenas com essa capacidade o servidor negocia o recurso 136 e envia um byte extra de raridade por item. Clientes antigos mantem o layout anterior. O cliente novo so le esse byte quando o servidor negocia o recurso. Isso exige recompilar servidor e OTC; Lua sozinha nao implementa o visual por instancia.

Implementacao e testes locais em branches proprias, sem alterar o Quente. A fonte do servidor e /home/baiakeros/baiakeros na WSL Ubuntu-24.04; o cliente e G:\otserv\otclient-main. Nenhuma fonte do Idler e usada.

## Validacao necessaria

Testar limites das chances, 1/2/3/4 atributos sem repeticao, quiver inclusa e municoes excluidas, grupos de vocacao, nao rerrolar, loot normal e boss, serializacao, equipar/desequipar sem acumular, transferencia e protecao de venda. Simular pelo menos 100 mil equipamentos. Conferir quatro cores no mesmo item e limpeza do slot. Registrar apenas as verificacoes realmente executadas; balanceamento e gameplay completos continuam dependendo de testes reais.
## Resultado da implementacao local — 05/11/2026

- Servidor Canary e OTC compilados com sucesso, em branches dudantas/item-rarity-20261105.
- Simulacao de 100.000 equipamentos: 40.041 Comuns, 29.814 Raros, 20.119 Epicos e 10.026 Ultras.
- Testados elegibilidade de quiver, grupos de atributos, quantidade exata por raridade, nao rerrolar e rotas de loot comum/boss.
- Teste nativo com 20 itens reais passou para boots, wand, bow, quiver e shield, incluindo clone, atributos serializados e transferencia para container.
- Conta/personagem descartaveis locais validaram equipar e desequipar vida, mana, shielding, magic level e distance de quiver; os valores voltaram ao normal ao remover, sem acumular.
- Dois logins reais validaram negociacao do recurso 136, recebimento do Ultra equipado no OTC e preservacao byte a byte dos atributos apos save/load do banco.
- Teste visual nativo passou nas quatro cores, copia da instancia e limpeza do fundo do slot. Hook central de UIItem e slots de inventario aplicam o visual em qualquer janela que receba a instancia.
- Regressoes de Warzone, entrega de itens e comandos de manutencao passaram.
- Conta, personagem, equipamento e credenciais descartaveis foram removidos ao terminar. Scripts temporarios sairam dos diretorios de autoload.
- Servidor local online com o novo executavel; environment.lua do OTC segue localhost. start.sh/recompile.sh nao foram alterados por esta entrega. Quente e Idler nao foram alterados.
- Nao foi feito teste de combate completo contra todos os bosses nem de compra/venda/cancelamento em todos os mercados. Mercado de commodities bloqueia itens com raridade; Market real usa serializacao existente e requer validacao funcional antes de publicar.

Captura visual: tools/rarity-client-profile-20261105/rarity-colors.png. Teste reproduzivel do servidor: tests/lua/item_rarity_spec.lua com LuaJIT. Teste de itens virtuais: tools/local-test/item_rarity.lua (fora do autoload). Teste visual OTC: tests/native/item_rarity.lua.
