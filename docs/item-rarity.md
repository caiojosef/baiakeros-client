# Raridades e atributos — Baiakeros Tibia nativo / OTC

Versão 4, implementada na WSL e publicada no Quente em 05/11/2026, com cliente/assets r43. Exclusiva do MMO Canary e OTC; não pertence ao Idler/mobile. Compilação nativa, reinício do serviço e atualização pública verificados.

## 1. Chances e quantidade de atributos

O monstro/boss primeiro calcula seu loot normal. Depois, cada equipamento elegível novo recebe exatamente um dos resultados abaixo. Não altera a chance original de o item cair nem multiplica novamente os bônus de loot/VIP.

| Resultado | Cor | Chance após cair | Atributos sorteados | Orçamento |
|---|---|---:|---:|---:|
| Normal | Sem cor de raridade | 55% | 0 | 0 |
| Common | Azul | 30% | 1–2 | 3 |
| Rare | Roxo | 10% | 2–3 | 5 |
| Epic | Amarelo | 4% | 3–4 | 8 |
| Ultra | Vermelho | 1% | 4 | 11 |

Atributos básicos custam 1 ponto; especializações, 2; premium, 3. Não há primeiro atributo obrigatório. O sorteio respeita quantidade, orçamento, perfil do equipamento e incompatibilidades. Efeitos premium entram a partir de Rare: até um no Rare e até dois no Epic/Ultra. Dois bônus Common pequenos não equivalem necessariamente a dois Rare.

Não repetir a mesma chave de atributo. Por item: no máximo uma especialização de ML, uma afinidade elemental ofensiva, uma magia/runa específica, uma categoria de redução de recarga e uma proteção. Ice ML e Ice Damage podem coexistir; Ice ML e Fire Damage não. Skill em armor de knight escolhe somente Sword, Axe ou Club por item.

O resultado normal também fica marcado como processado, sem nome, cor ou bônus extra. Pegar, transferir, equipar ou reabrir o container não permite tentar novamente. Os requisitos de nível/vocação e atributos originais continuam valendo.

## 2. Equipamentos e compatibilidade

Entram helmet, armor, legs, boots, shield/spellbook, sword/axe/club, distance, wraps de monk, wand/rod e quiver. Quiver preserva munição e capacidade. Ficam fora rings, amulets, backpacks e outros containers, munições, runas, exercícios/training weapons, moedas, consumíveis e produtos de criatura.

| Perfil | Atributos disponíveis, conforme as restrições da peça |
|---|---|
| Rod / wand | ML geral/especializado, dano da afinidade, runas, magias do perfil, cooldown, custo de mana, crítico/leech e recursos |
| Spellbook | ML, mana, runas, proteção, cura compatível e utilidade de mage; sem Shielding/Defense |
| Sword / axe / club | Attack, skill correspondente, dano básico/físico/elemental compatível, spells de knight, velocidade, crítico/leech e recursos |
| Bow / crossbow | Distance, Attack, dano básico/físico/holy, spells de paladin, velocidade, crítico/leech e recursos |
| Quiver | Distance, Holy ML, dano básico/holy, spells de paladin, velocidade, crítico/leech e recursos |
| Shield físico | Defense, Shielding, proteção, recursos e utilidade; restrição da peça pode acrescentar bônus da classe |
| Armor / helmet / legs de mage | ML, magia/runa compatível, proteção, custo de mana, regeneração e recursos |
| Armor / helmet / legs de knight | Uma skill de arma, magias de knight, proteção, regeneração e recursos |
| Armor / helmet / legs de paladin | Distance, Holy ML, magias de paladin, proteção, regeneração e recursos |
| Wraps / peças de monk | Fist, magias de monk, proteção/recursos conforme a peça; wraps também recebem bônus de arma |
| Boots | Recursos, proteção, regeneração e caminhada; peças exclusivas também podem receber skill/ML da classe, sem dano/cooldown premium |
| Peças universais | Recursos, Armor, proteção e regeneração; peças defensivas fora de boots/spellbook podem receber Shielding |

A seleção depende do equipamento, não de quem matou o monstro. Rod/wand com elemento nativo reconhecido prioriza esse elemento. Peças exclusivas de sorcerer recebem Fire/Energy/Death; druid, Earth/Ice; paladin, Holy. Peças de mage compartilhadas não recebem uma spell exclusiva de apenas uma vocação. Runas utilizáveis por mages têm catálogo próprio.

Loot comum, loot aninhado e recompensa de boss usam a mesma regra. Bag You Desire, Primal Bag e Bag You Covet rolam o equipamento antes de entregá-lo, incluindo o resultado normal. Falta de espaço/falha de criação preserva a bolsa. Arcane Bag mantém seu fluxo separado. Loja/NPC/quest/comando antigo não reclassificam automaticamente seus itens.

## 3. Vida e mana acima de 100

Faixas novas antes do ajuste pelo nível mínimo do equipamento:

| Bônus | Common | Rare | Epic | Ultra |
|---|---:|---:|---:|---:|
| Maximum Health | +110–160 | +180–280 | +300–450 | +500–750 |
| Maximum Mana | +130–200 | +220–360 | +400–600 | +650–1.000 |

Bandas: nível mínimo 0–49 = 0; 50–149 = 1; 150–299 = 2; 300+ = 3. Cada banda acrescenta +25 ao intervalo de vida e +40 ao de mana. Assim, Ultra de nível 300+ pode sortear +575–825 Maximum Health ou +770–1.120 Maximum Mana. O nível do personagem e o forge tier não alteram essa banda.

São valores máximos adicionais enquanto equipado, não cura ou recuperação imediata. Equipar/desequipar não enche vida/mana. Não há garantia de sortear recursos em todo item. Itens antigos mantêm os valores que já tinham.

## 4. Catálogo completo de bônus novos

Todos os nomes exibidos abaixo estão em inglês. As faixas são por raridade e só aparecem nos perfis compatíveis.

### Base, skills e magia

- Maximum Health; Maximum Mana.
- Attack; Armor; Defense; Movement Speed.
- Sword Fighting; Axe Fighting; Club Fighting; Distance Fighting; Fist Fighting; Shielding.
- Magic Level.
- Fire Magic Level; Earth Magic Level; Energy Magic Level; Ice Magic Level; Holy Magic Level; Death Magic Level; Healing Magic Level.
- Health Regeneration; Mana Regeneration — quantidade a cada 10 segundos, fora de combate e fora de protection zone.

Skill: +1 / +1 / +1–2 / +2–3; teto adicional +10 por skill no conjunto. ML geral: Rare +1, Epic +1–2, Ultra +2, teto +6 no conjunto. ML especializado: +1 / +1–2 / +2–3 / +3–4, teto +10 por especialização.

ML especializado entra apenas na fórmula nativa que usa ML e o elemento correspondente. +3 Ice Magic Level não significa +3% de dano e não aumenta uma fórmula física de knight baseada em skill/attack. Healing ML melhora fórmulas de cura que usam ML, não dano.

Attack usa aproximadamente 1–5% do ataque base, arredondado com mínimo +1, conforme a raridade. Armor/Defense: +1 / +1–2 / +2–3 / +3–4, mais +1 a partir da banda 2. Movement Speed: +1–2 / +2–3 / +3–4 / +4–5, mais até +1. Regeneração: +2–4 / +4–7 / +6–10 / +8–14, mais +2 por banda. Relógio único por personagem impede acelerar regeneração trocando equipamento.

### Dano por origem e elemento

- Basic Attack Damage.
- Offensive Spell Damage.
- Offensive Rune Damage.
- Wand and Rod Damage.
- Physical Damage; Fire Damage; Earth Damage; Energy Damage; Ice Damage; Holy Damage; Death Damage.

Dano amplo premium: Rare +0,50–1%, Epic +1–2%, Ultra +2–3%. Dano elemental: Common +0,25–0,50%, Rare +1–2%, Epic +2–3%, Ultra +3–4%; Physical segue +0,25–0,50 / +0,50–1 / +1–2 / +2–3%.

O modificador é aplicado a cada parcela compatível do golpe. Não converte o elemento do item. Básico, spell e rune são origens distintas. Os bônus de dano da raridade somam uma vez antes de aplicar: teto +8% por origem ampla, +12% por elemento, +15% por magia específica e +25% combinados no mesmo componente. Exemplo: +3% Rune, +4% Ice e +6% Avalanche = +13% na parcela de gelo da Avalanche.

### Runas específicas

- Avalanche Rune Damage.
- Great Fireball Rune Damage.
- Thunderstorm Rune Damage.
- Stone Shower Rune Damage.
- Sudden Death Rune Damage.
- Icicle Rune Damage.
- Heavy Magic Missile Rune Damage.

Faixas: Rare +2–3%, Epic +3–4,50%, Ultra +4,50–6%. Afetam o uso ofensivo da runa nomeada; não a magia que cria a runa, cargas, cura ou outras runas.

### Magias específicas

| Vocação do equipamento | Magias com bônus Damage e Mana Cost Reduction |
|---|---|
| Sorcerer | Energy Wave; Great Energy Beam; Hell's Core; Rage of the Skies |
| Druid | Ice Wave; Terra Wave; Eternal Winter; Wrath of Nature |
| Knight | Berserk; Fierce Berserk; Groundshaker; Front Sweep; Brutal Strike; Annihilation |
| Paladin | Divine Caldera; Divine Grenade; Ethereal Spear; Strong Ethereal Spear; Divine Barrage |
| Monk | Flurry of Blows; Sweeping Takedown; Thousand Fist Blows |

Nomes como Fierce Berserk Damage são percentuais no resultado da magia, com a mesma faixa das runas específicas. Não simulam ML para exori gran. Mana Cost Reduction da magia nomeada: Rare +0,50–1%, Epic +1–2%, Ultra +2–3%.

Druid também pode receber Heal Friend Effectiveness e Mass Healing Effectiveness: Rare +0,50–1%, Epic +1–2%, Ultra +2–3%. Reconhecimento pela identidade canônica da magia, independente de maiúsculas, espaços e apóstrofos. Não copiar bônus para magias de familiar/reflexo por coincidência.

### Ritmo, crítico, sustain e proteção

- Attack Speed.
- Offensive Rune Cooldown Reduction.
- Offensive Spell Cooldown Reduction.
- Spell Mana Cost Reduction.
- Critical Hit Chance; Critical Extra Damage.
- Life Leech Amount; Mana Leech Amount.
- Healing Received.
- Physical Protection; Fire Protection; Earth Protection; Energy Protection; Ice Protection; Holy Protection; Death Protection; Life Drain Protection.

| Família | Faixa por item (Rare / Epic / Ultra) | Teto adicional no conjunto |
|---|---|---|
| Attack Speed / Offensive Rune Cooldown Reduction | 3–6 / 6–9 / 9–12%, mais 0,60% por banda | 25% separados; piso de 1500 ms |
| Offensive Spell Cooldown Reduction | 0,50–1 / 1–1,50 / 1,50–2%, mais 0,10% por banda | 5%; piso nativo preservado |
| Critical Hit Chance | 0,25–0,40 / 0,40–0,60 / 0,60–0,75 ponto percentual | +2 pontos percentuais |
| Critical Extra Damage | 1–1,50 / 1,50–2,25 / 2,25–3 pontos percentuais | +10 pontos percentuais |
| Life/Mana Leech Amount | 0,25–0,50 / 0,50–0,75 / 0,75–1 ponto percentual | +3 pontos por tipo |
| Spell Mana Cost Reduction | 0,50–1 / 1–2 / 2–3% | 8%, somado à redução específica |
| Healing Received / cura específica | 0,50–1 / 1–2 / 2–3% | 8% por categoria |
| Physical Protection | 0,50–0,75 / 0,75–1 / 1–1,50% | 4% |
| Proteção elemental | 1–1,50 / 1,50–2,25 / 2,25–3% | 8% por elemento |
| Life Drain Protection | 0,50–1 / 1–2 / 2–3% | 8% |

Common também pode sortear proteção: física 0,25–0,50%, elemental 0,50–1%, life drain 0,25–0,50%. Healing Received aumenta cura por magia/runas nomeadas, não poções/leech. Custo de mana aplica-se a instant spells; custo positivo não fica menor que 1. Leech segue chance e redução de área nativas, sem garantir recuperação em cada acerto.

Ataque automático e runas de base 2.000 ms: 10% → 1.800 ms; 20% → 1.600 ms; 25% → 1.500 ms. Uma runa de 6.000 ms com 25% continua em 4.500 ms. Instant spells mantêm o teto de 5% e piso do grupo Attack de 1.000 ms. Cura, suporte e grupos secundários conservam seus cooldowns. Se a regra nativa já estiver abaixo do piso, a raridade não aumenta nem reduz esse intervalo.

Os bônus percentuais de dano funcionam no caminho nativo de combate, inclusive PvP após suas regras existentes; não há multiplicador PvP exclusivo. ML, crítico e velocidade podem elevar DPS além do teto percentual de dano. Esta calibração publicada continua sujeita à avaliação de gameplay e ajustes de balanceamento.

## 5. Persistência, compatibilidade e visual

Versão, resultado, perfil, banda, origem, chaves/valores, quantidade e orçamento ficam na instância. Equipar aplica e desequipar remove. Apenas slots de combate contam, nunca backpack/depot. Os bônus originais, imbuements, resistências e regras de vocação continuam separados.

Itens anteriores não recebem novos atributos nem vida/mana maiores retroativamente. A conversão v3 de velocidade pré-v3 continua idempotente (multiplica uma vez por seis os rolls antigos até 2,30%). Outros números/raridades originais são preservados. Texto em inglês mantém o detalhe original do item.

O OTC recebe a mesma raridade por instância pelo protocolo bkrarity1 / recurso 136. Fundo e borda usam as quatro cores; slots normais/vazios limpam a cor. Arrastar/soltar não apaga a borda persistente. O tooltip orienta usar Look, sem prometer quantidade fixa de bônus; a lista completa está no Look.

Rashid aceita Normal/Common/Rare/Epic/Ultra pelo preço original do catálogo, inclusive em Sell All. Outros NPCs mantêm sua política anterior de raridades. Forge e imbuements ativos continuam protegidos. Mercado de commodities bloqueia raridades; troca direta e Market real preservam atributos serializados. Nenhum bônus de preço NPC foi adicionado.

## 6. Comando /i para testes

A sintaxe antiga continua. Para forçar uma raridade com atributos aleatórios novos:

```text
/i bow, 1, ultra
/i quiver, 1, epic
/i wand of vortex, 1, rare
/i 53226, 1, ultra
```

Também aceita `/i item, quantidade, forgeTier, raridade`. Nomes Common/Rare/Epic/Ultra e aliases portugueses continuam disponíveis. `random` segue as chances novas e pode gerar normal. Cada instância tem seu próprio sorteio; não rerrola equipamento existente.

## 7. Validação e fontes

- Compilação release nativa da WSL concluída com o cache existente.
- 54.400 combinações de equipamento/raridade/banda verificam contagem, orçamento, incompatibilidades, faixas e preservação de itens antigos.
- Simulação de 100 mil drops verifica distribuição 55/30/10/4/1.
- Teste C++ independente verifica soma única, categorias/elementos, identificação de magias, caps, custo de mana e piso de 1500 ms.
- Testes de /i, reward bags, Arcane Bag e manutenção preservados.
- Cliente real 15.11: recursos acima de 100 sem cura ao equipar; Avalanche/Ice sem aumentar GFB; Fierce Berserk separado de Berserk; Ice ML chega à fórmula e sai ao desequipar; crítico/leech nas unidades nativas; Heal Friend, Healing Received e Fire Protection; serialização e relogin do loot v4.

Fontes: `data/libs/systems/item_rarity.lua`, `src/utils/rarity_effects.hpp`, integração em Player/Combat/Spell/Movement; no OTC, `modules/game_interface/widgets/uiitem.lua`. Os testes manuais ficam em `tools/local-test`, fora do autoload. Nenhum dado de conta/banco/credencial faz parte do código.

Executar na raiz do servidor:

```sh
luajit tests/lua/item_rarity_spec.lua
g++ -std=c++20 -Isrc tests/unit/utils/rarity_effects_standalone.cpp -o /tmp/rarity-effects-test
/tmp/rarity-effects-test
g++ -std=c++20 -Isrc tests/unit/utils/rarity_balance_standalone.cpp -o /tmp/rarity-balance-test
/tmp/rarity-balance-test
```

Não usar `-DNDEBUG` nos testes independentes, que usam assert. Balanceamento em combate contínuo, medição real de intervalos, regeneração temporizada e custo de casts reais devem ser avaliados em gameplay; os testes matemáticos não substituem essa avaliação.

## 8. Produção anterior, separada desta implementação

Em 05/11/2026 a v3 foi publicada e reiniciada no Quente por solicitação anterior, com Common 85% / Rare 10% / Epic 4% / Ultra 1% e cliente/assets r42. Runtime do servidor: d2312a552ab8698cb37b49373e1629d4cad60b98; cliente: c392611e501981dab03431d94108dec8a9213073. PRs anteriores: https://github.com/caiojosef/baiakeros/pull/16 e https://github.com/caiojosef/baiakeros-client/pull/20. Esta v4 não atualiza essas publicações automaticamente.

Trabalho v4 enviado à branch `dudantas/item-affixes-v4-20261105` em ambos os repositórios. Não alterados start.sh, recompile.sh nem os endpoints localhost nesta implementação. Backup local do executável e dos relatórios anteriores em G:/otserv/BACKUPS/antes-rarity-v4-20261105.

## 9. Publicação v4 / r43 em 05/11/2026

Publicação e reinício explicitamente autorizados pelo usuário. O Quente recebeu a distribuição Normal 55% / Common 30% / Rare 10% / Epic 4% / Ultra 1%, pools de atributos com orçamento e recursos novos acima de 100.

Fonte de runtime do servidor: `d78c26f679356ae4d1bdce6dc35fa0cad6ba58c2`. Executável compilado no próprio Quente, SHA-256 `2249696b4b5c2e0c6110fc35335ae323e2efd1bd30f4b37dd6122ba330a0af0e`. Serviço canary ativo, portas 7171/7172 abertas e inicialização sem erros. O novo drop-in do serviço permite reverter para o executável anterior.

Cliente de produção na revisão 43, fonte `f9157456c3fd59517c118384502b022979577d65`. O empacotador gera init.lua com revisão 43 apenas no artefato e usa environment.production.lua; o ambiente localhost do checkout continua preservado. Ambos os manifestos públicos estão em 43, com 16.332 arquivos, dois pacotes alterados e nenhuma exclusão.

Pacotes alterados: init.lua e modules/game_interface/widgets/uiitem.lua. Todos passaram por tamanho/hash compactado e descompactado via HTTPS público. A configuração de produção também foi verificada pelo pacote publicado. O teste real do updater TestPublishedNativePackages passou, incluindo o caminho com #. Nenhuma recompilação do OTC foi necessária para esta mudança de Lua; o executável com suporte à raridade por instância permanece o mesmo.

Os testes Lua de raridade, bolsas, /i, Arcane Bag e manutenção, e os testes C++ de cálculo, passaram também no Quente antes do reinício. Os hashes de start.sh, recompile.sh, config.lua e market.local.lua foram preservados. Banco e mapas não foram substituídos.

Backup remoto: /var/backups/baiakeros/rarity-r43-20261105, incluindo código anterior, definição do serviço, manifestos anteriores, configuração nginx e registro de ativação. O cliente e os assets foram publicados após o servidor ficar saudável. Para receber a atualização, fechar o OTC e abrir novamente pelo launcher.

PRs: https://github.com/caiojosef/baiakeros/pull/17 e https://github.com/caiojosef/baiakeros-client/pull/21. Os commits estão nas branches de trabalho; merge na main depende de revisão e solicitação. Os PRs incluem a base de raridade dos PRs anteriores #16/#20, que deve ser considerada na ordem de integração.

## Correção do Rashid publicada em 06/11/2026

Rashid aceita itens com raridade do seu catálogo pelo preço normal. Sell All confirma a redução real, repete vendas parciais/rejeitadas e verifica sobras, respeitando blacklist e equipamentos ignorados. O catálogo de abertura inclui tipos que só possuem cópias coloridas. Publicação de servidor e cliente/assets r44 validada; detalhes em docs/rashid-sales.md (cliente) e docs/systems/rashid-sales.md (servidor). As chances de drop do Quente foram preservadas.
