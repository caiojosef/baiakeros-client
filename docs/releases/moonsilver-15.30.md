# Moonsilver 15.30 — preparação para atualização

Data: 27/09/2026. Pacote r30 preparado localmente em site-update; publicação no site não realizada nesta etapa.

## Entrega

- 11 armas Moonsilver e 11 versões Stellar; level 1000, vocações, peso, elementos, defesa, atributos, classe 4 e slots/restrições de imbuement.
- 5 capacetes Moonsilver; level 800 e augments específicos.
- 5 famílias de amuletos: base, enchanted e exhausted; level 270 e duração de 3 horas nas versões enchanted.
- Auric Moon Sigil, ID 54480.
- 22 árvores de proficiência oficiais importadas, com 7 níveis cada.
- Bônus de homing missile com chance e multiplicador definidos na árvore. Dispara após um acerto de magia ofensiva; dano elemental de 200% ou 300% do level, conforme perk. Não dispara por cura ou ataque básico. O gatilho usa ORIGIN_SPELL, a origem de combate das magias e runas ofensivas no Canary.
- Thousand Fist Blows, ID 301, necessário aos augments do Katar/Strike Helm. Incluído também no catálogo de magias do cliente.

## Forja Stellar — adaptação do Baiakeros

Usar o Auric Moon Sigil diretamente sobre a arma Moonsilver normal no inventário.
A receita consome 1 arma Moonsilver, 1 Soul correspondente, 1 Sanguine correspondente e 1 sigil; entrega a versão Stellar no mesmo slot.
Esta é uma ação customizada, sem NPC, quest, taxa em gold ou condição de boss. A implementação futura da quest poderá reutilizar as receitas.

Os materiais precisam pertencer ao jogador e estar sem tier e sem imbuements, evitando perda de upgrades. Falhas de consumo desfazem a transformação e devolvem os materiais já removidos. Não exige slot extra na backpack.

| Arma | Moonsilver | Soul | Sanguine | Stellar |
| --- | ---: | ---: | ---: | ---: |
| Epee | 53207 | 34082 | 43864 | 53208 |
| Claymore | 53209 | 34083 | 43870 | 53210 |
| Axe | 53211 | 34084 | 43868 | 53212 |
| Chopper | 53213 | 34085 | 43874 | 53214 |
| Crusher | 53215 | 34086 | 43866 | 53216 |
| Mace | 53217 | 34087 | 43872 | 53218 |
| Channeler | 53219 | 34090 | 43882 | 53220 |
| Sceptre | 53221 | 34091 | 43885 | 53222 |
| Katar | 53223 | 50159 | 50157 | 53224 |
| Bow | 53225 | 34088 | 43877 | 53226 |
| Crossbow | 53227 | 34089 | 43879 | 53228 |

## Cliente r30

Pasta de publicação: `D:\otserv\site-update\downloads\client`.
Também espelhado em `D:\otserv\site-update` conforme a estrutura anterior.
Publicar os arquivos de `downloads/client` em `/downloads/client/` do site, enviando os packages primeiro e os manifests por último.

- 43 aparências de item, 2 projéteis e 8 folhas de sprites oficiais.
- As 3 folhas dos projéteis usam intervalos novos; os intervalos existentes foram preservados.
- 22 proficiências adicionadas ao catálogo do cliente, mantendo as demais.
- Corrigidos os códigos de Alpha Strike (28), Omega Strike (29), Armor Penetration (30), Elemental Pierce (31) e Homing Missile (32), para coincidir com o servidor.
- Corrigidos tooltips dos projéteis, penetração e magias da atualização.
- Dados normais e sidecars LZMA sincronizados; manifests contêm hashes dos arquivos realmente distribuídos.
- Assets continuam em `data/things/1525/`; protocolo permanece 15.11. Sem alterar a política de hashes ou criar novo diretório permanente de assets.
- Não houve mudança no C++ do OTC; o executável existente foi mantido e os dados/Lua foram reempacotados. Launcher mantido, sem recompilação.

## Servidor

Compilado com `cmake --build --preset linux-release --target canary -j4`.
Binário: `/home/baiakeros/baiakeros/build/linux-release/bin/canary`.
SHA-256: `3de504a416033b4b21a31b7795af268fa19fac80be3adbb2c4679dd44661d502`.

Para instalar em outra instância, levar o binário e os arquivos:

- `data/items/items.xml`
- `data/items/proficiencies.json`
- `data/items/appearances.dat`
- `data/scripts/spells/attack/thousand_fist_blows.lua`
- `data-otservbr-global/scripts/actions/other/stellar_moonsilver_forge.lua`

Também foi corrigido `item:getImbuement()` no C++: quando o slot está vazio agora retorna nil, em vez de devolver acidentalmente o próprio userdata do item. Rods usam o tipo interno wand, como exige o carregador do Canary; sua categoria e vocação permanecem de rod/druid.
O binário contém as demais alterações já existentes no checkout atual.

## Verificação

- Build Linux release concluído.
- Teste Lua da forja: 11 receitas, materiais ausentes, propriedade, tier/imbuements e rollback passaram.
- Teste Lua dos tooltips: homing missile, penetração elemental, Alpha/Omega e augments passaram.
- OTC executado com perfil de teste isolado: 43 aparências, 22 árvores, 2 projéteis e todos os tooltips carregados; encerramento limpo.
- Folhas oficiais verificadas pelo hash do download e do BMP descomprimido.
- Todos os packages são verificados por tamanho, SHA-256 e descompressão contra o manifesto; cópia espelhada também verificada. 16.295 arquivos verificados. Detalhes em `manifest-report.json` e `compression-report.json`.
- Não foi realizado combate de ponta a ponta com jogador conectado. O cliente de teste apresentou um aviso antigo do calendário de eventos (JSON remoto inválido), sem erro no carregamento dos itens.

## Limite conhecido e escopo reservado

Pesquisa revisada em 27/09/2026: a Channeler estava usando energy tanto no projétil quanto no dano; foi corrigida para **death**. Proteção contra energy não é o elemento do ataque. A Sceptre usa **ice**. Alcance 6, level 1000, vocações, imbuements, bônus e proficiências permanecem preservados.

O dataset comunitário de mitigação `muriloricci/mitigation` registra tiro básico **103–133 death para Moonsilver Channeler** e **103–127 ice para Moonsilver Sceptre**. Esses intervalos foram aplicados em substituição ao intervalo copiado da Sanguine Coil (113–125). É uma referência comunitária publicada durante o teste do update, sem amostras de combate anexadas; não equivale a confirmação oficial da CipSoft.

| Arma | Dano básico configurado | Elemento | Mana por tiro | Situação da fonte |
| --- | --- | --- | ---: | --- |
| Moonsilver Channeler (53219) | 103–133 | death | 21 | Intervalo do dataset comunitário; mana não confirmada |
| Stellar Moonsilver Channeler (53220) | 103–133 | death | 21 | Reutiliza o tiro normal como adaptação local; mana não confirmada |
| Moonsilver Sceptre (53221) | 103–127 | ice | 21 | Intervalo do dataset comunitário; mana não confirmada |
| Stellar Moonsilver Sceptre (53222) | 103–127 | ice | 21 | Reutiliza o tiro normal como adaptação local; mana não confirmada |

**Pendência de fidelidade ao global:** não foi encontrada confirmação do consumo de mana nem de um intervalo próprio para as Stellar. Os 21 de mana foram mantidos para funcionamento local, sem inventar um valor novo. As páginas do update e dos itens não informam esses números, e os arquivos oficiais de aparência/proficiência não contêm os parâmetros do ataque básico. Para retirar essa ressalva, ainda é necessário um registro de tiros sem bônus/críticos em alvo de resistência conhecida e consumo de mana isolado, ou uma fonte confiável que publique esses dados.

Os quatro cadastros foram conferidos contra o importador atualizado; a alteração preservou todos os outros atributos e todos os outros itens. Esta correção é de XML: exige reiniciar o servidor para carregar os novos ataques; não exige recompilar o Canary nem atualizar o cliente.

Como solicitado, não foram adicionados monstros, bosses, quests nem drops. Os itens podem ser criados por `/i <ID>` por administrador e as receitas podem ser testadas com os materiais criados pelo comando.

## IDs implementados

| ID | Item | Level | Slots de imbuement | Proficiência |
| ---: | --- | ---: | ---: | ---: |
| 53197 | enchanted flamingo amulet of valor | 270 | 0 | — |
| 53198 | enchanted flamingo amulet of valor | 270 | 0 | — |
| 53199 | enchanted flamingo amulet of precision | 270 | 0 | — |
| 53200 | enchanted flamingo amulet of precision | 270 | 0 | — |
| 53201 | enchanted flamingo amulet of destruction | 270 | 0 | — |
| 53202 | enchanted flamingo amulet of destruction | 270 | 0 | — |
| 53203 | enchanted flamingo amulet of nature | 270 | 0 | — |
| 53204 | enchanted flamingo amulet of nature | 270 | 0 | — |
| 53205 | enchanted swan amulet of balance | 270 | 0 | — |
| 53206 | enchanted swan amulet of balance | 270 | 0 | — |
| 53207 | moonsilver epee | 1000 | 2 | 478 |
| 53208 | stellar moonsilver epee | 1000 | 2 | 489 |
| 53209 | moonsilver claymore | 1000 | 3 | 485 |
| 53210 | stellar moonsilver claymore | 1000 | 3 | 496 |
| 53211 | moonsilver axe | 1000 | 2 | 475 |
| 53212 | stellar moonsilver axe | 1000 | 2 | 486 |
| 53213 | moonsilver chopper | 1000 | 3 | 480 |
| 53214 | stellar moonsilver chopper | 1000 | 3 | 491 |
| 53215 | moonsilver crusher | 1000 | 2 | 476 |
| 53216 | stellar moonsilver crusher | 1000 | 2 | 487 |
| 53217 | moonsilver mace | 1000 | 3 | 482 |
| 53218 | stellar moonsilver mace | 1000 | 3 | 493 |
| 53219 | moonsilver channeler | 1000 | 2 | 479 |
| 53220 | stellar moonsilver channeler | 1000 | 2 | 490 |
| 53221 | moonsilver sceptre | 1000 | 2 | 477 |
| 53222 | stellar moonsilver sceptre | 1000 | 2 | 488 |
| 53223 | moonsilver katar | 1000 | 3 | 484 |
| 53224 | stellar moonsilver katar | 1000 | 3 | 495 |
| 53225 | moonsilver bow | 1000 | 3 | 481 |
| 53226 | stellar moonsilver bow | 1000 | 3 | 492 |
| 53227 | moonsilver crossbow | 1000 | 3 | 483 |
| 53228 | stellar moonsilver crossbow | 1000 | 3 | 494 |
| 53229 | moonsilver battle visor | 800 | 2 | — |
| 53230 | moonsilver trail hood | 800 | 2 | — |
| 53231 | moonsilver nimbus hat | 800 | 2 | — |
| 53232 | moonsilver spirit mask | 800 | 2 | — |
| 53233 | moonsilver strike helm | 800 | 2 | — |
| 54510 | flamingo amulet of valor | 270 | 0 | — |
| 54511 | flamingo amulet of precision | 270 | 0 | — |
| 54512 | flamingo amulet of destruction | 270 | 0 | — |
| 54513 | flamingo amulet of nature | 270 | 0 | — |
| 54514 | swan amulet of balance | 270 | 0 | — |
| 54480 | auric moon sigil | — | 0 | — |

## Fontes

- Dados oficiais do cliente Tibia, pacote 15.33.6ef2e8: importação seletiva das aparências da família 15.30 e das árvores; hashes do manifesto oficial.
- [Summer Update 2026 — anúncio oficial](https://www.tibia.com/news/?id=8845&subtopic=newsarchive).
- [Ajustes oficiais durante o teste](https://www.tibia.com/news/?id=8819&subtopic=newsarchive).
- [Tabela do update 15.30](https://www.tibiawiki.com.br/wiki/Updates/15.30.a30dad).
- [Make Believe e receitas Stellar](https://www.tibiawiki.com.br/wiki/Make_Believe_Quest).

- [Dataset comunitário: Channeler 103–133 death](https://github.com/muriloricci/mitigation/commit/462767bbbdad74629b92e43a397a80a81e84b364).
- [Dataset comunitário: Sceptre 103–127 ice](https://github.com/muriloricci/mitigation/commit/5e045d2fd006031dd3c4f2936dd967e2e9e3397b).

## Arquivos do cliente no GitHub

As aparências, o catálogo, as proficiências e as sete folhas de sprites desta atualização são versionados em `data/things/1525/`, junto com suas versões comprimidas disponíveis. Os demais assets da instalação base continuam seguindo a distribuição existente do cliente. Os caminhos finais permanecem OTC-standard; as opções de verificação estrita não foram alteradas.
