# Party Hunt: acompanhamento, Druid, Sorcerer e Paladin

O líder da party inicia Party Hunt. Pode andar manualmente ou usar Cavebot:
os controles são independentes. Os membros com o cliente atualizado acompanham
automaticamente, sem abrir o Helper. A party tem no máximo quatro personagens,
incluindo o líder; qualquer vocação pode liderar.

Start mantém as escolhas do líder: Auto Attack e Enable Shooter Helper são
sincronizados separadamente nos membros. Habilitar somente um deles não liga o outro.
Alterações do líder durante a sessão são propagadas; membros ativos seguem essas escolhas.
Configure antes as magias, runas e cura no Helper. Durante o acompanhamento,
os membros atacam o mesmo monstro visível selecionado pelo líder, mesmo quando
ele ataca manualmente com Auto Attack desligado. Trocar ou cancelar o alvo do
líder atualiza o alvo dos membros. Sem um alvo válido, não escolhem outro monstro.
Esse alvo compartilhado não liga Auto Attack nem Shooter: as magias e runas
continuam dependendo da escolha de Enable Shooter Helper do líder.
Ao pausar o acompanhamento, o membro volta a escolher seu alvo manualmente.
Party Hunt movimenta os membros, sem mover o próprio líder.
Dentro de PZ, Auto Attack e Shooter ficam desativados. As escolhas do líder são
guardadas para retomar somente quando ele e o próprio membro estiverem fora de PZ.
Enquanto o líder está em PZ, os seguidores aguardam em tiles protegidos próximos,
preferindo dois SQMs de distância: não orbitam nem procuram formação ofensiva.
O servidor fornece uma máscara dos tiles protegidos; sem essa informação, aguardam.
Resgates com o líder em PZ também usam somente tiles protegidos livres, sem sair
do PZ para atingir uma distância exata. A fila de alavanca respeita essa restrição.
Stop Party Hunt encerra o acompanhamento e restaura os controles anteriores
de cada participante. Stop no Cavebot não encerra Party Hunt.

## Janela e movimento compartilhado

Ao iniciar, todos recebem a janela reduzida com tempo restante e os quatro nomes,
com o líder primeiro. Back to Helper abre a aba Party Hunt; Expand mostra detalhes.
Somente o líder controla Start/Stop do grupo. Membros podem pausar e retomar apenas seu acompanhamento na janela minimizada. Cada jogador configura suas próprias
opções em Extras, independentemente das escolhas dos outros membros ou do líder.
Knight e Elite Knight não possuem essas opções de distância e recuo; o servidor
também rejeita alterações enviadas por essas vocações.
As preferências ficam no KV persistente de cada personagem, sem tabela adicional,
e continuam válidas ao relogar ou trocar de líder.

O acompanhamento procura um espaço livre a três SQMs do líder. O contorno usa
três SQMs com baixa pressão, quatro quando passa da tolerância e até cinco com
pressão muito alta ou vida crítica. Tanto a formação quanto o contorno exigem
linha de visão para a box: uma posição atrás da parede não vale só porque tem a
distância correta. Caminhos a partir de posições visíveis mantêm essa visão;
se o líder mudar de lugar e ocultar a box, procura uma passagem para recuperá-la.
A movimentação atualiza a cada 50 ms, respeitando duração e confirmação dos passos
do servidor. O caminho evita buracos, criaturas e paredes. Durante o contorno,
monstros nos SQMs laterais não bloqueiam uma diagonal com destino livre;
o terreno lateral continua sendo verificado para evitar cortar paredes ou buracos.

O servidor consulta o mapa real de dano do personagem. Um monstro precisa ter
causado dano nesse personagem recentemente (janela de quatro segundos) para entrar
na contagem. Dano de área também conta, mesmo mirando o líder. Apenas mirar,
ou estar na box do EK, não basta.
Ao iniciar a sessão, o histórico anterior é usado como base e não conta como dano
novo. Dano à vida ou à mana por ataques também é considerado.

Em Extras, **Run from (monsters)** escolhe de um a seis monstros para iniciar a
fuga. O valor é inclusivo: configurando **três**, fica parado com um ou dois
atacantes e começa a contornar no terceiro. Configurando um, corre desde o
primeiro; configurando seis, começa no sexto. Ao cair abaixo do valor escolhido,
retorna à formação. Always run ignora essa contagem
e mantém o contorno enquanto há monstros, usando as runas configuradas no Helper.
Não habilita runas que o jogador deixou desligadas.

O contorno prefere o sentido horário. Pressão alta ou vida crítica podem ampliar
o afastamento, sem sair do máximo de cinco SQMs da box. Só inverte o sentido para
contornar um lado bloqueado; mantém esse desvio brevemente para evitar ficar
indo e voltando entre os mesmos tiles. As decisões respeitam a velocidade
e a confirmação dos passos do servidor. Cura e ataques pertencem ao Helper.

## Formação de Druid / Elder Druid e Sorcerer / Master Sorcerer

Quando o líder para, ED e MS procuram a posição cardinal livre e alcançável mais
próxima: norte, sul, leste ou oeste, a **três SQMs entre as posições dos personagens**.
Param olhando para a box. Uma posição diagonal não é escolhida para ficar parado.
Sem magia pronta, mantém a posição visível atual e olha para a box; não se aproxima
para uma magia em cooldown. Ao acompanhar o líder, busca a formação a três SQMs.

O Druid consulta a próxima magia elegível da rotação real do Shooter: habilitação,
prioridade, mana, número mínimo de monstros e cooldown individual e de todos os
grupos da magia, incluindo os grupos de ultimates e Ulus. Só uma magia pronta
provoca reposicionamento. Sua distância desejada, enquanto está parado, é:

- `exevo tera hur`: quatro SQMs.
- `exevo gran frigo hur`: três SQMs.
- `exevo gran mas frigo` e `exevo gran mas tera`: dois SQMs.
- `exevo ulus frigo` e `exevo ulus tera`: três SQMs.
- Demais magias: três SQMs.

O Sorcerer / Master Sorcerer também consulta a próxima magia pronta do Shooter:

- `exevo vis hur` e `exevo gran flam hur`: quatro SQMs, na mesma posição
  de `exevo tera hur`, virado para a box.
- `exevo flam hur` e `exevo infir flam hur`: dois SQMs, virado para a box.
- `exevo vis lux` e `exevo max mort`: três SQMs, alinhado com a box.
- `exevo gran vis lux` sem Beam Mastery: a partir do alinhamento de quatro
  SQMs, desloca um SQM lateralmente e dispara paralelo ao eixo da box. Escolhe
  a fileira lateral com mais monstros atingidos, considerando caminho livre
  e visibilidade; mantém o lado atual em empate. Com Beam Mastery ativo na
  Wheel, permanece alinhado a quatro SQMs, na posição do Terra Hur.
- `exevo gran mas flam` e `exevo gran mas vis`: dois SQMs.
- Death Echo, magias no alvo e demais magias: formação padrão de três SQMs,
  respeitando o alcance e a área da magia; ataques no alvo não exigem uma wave.

Sem pressão, escolhe a posição cardinal livre mais próxima. Ao atingir o limite
de monstros de Extras, contorna a box entre três e cinco SQMs, com pequenas
paradas para lançar magias prontas que atinjam os monstros. Always Run conserva
o uso de runas e evita as paradas para magias, como nas demais vocações à distância.
As magias e os ataques continuam vindo do Shooter, não
de um lançador novo no Party Hunt. As áreas reais e o mínimo de inimigos
configurado no Helper continuam valendo: o movimento não falsifica a cobertura.
O servidor informa o bônus real de Beam Mastery em cada status do Party Hunt.
O Shooter usa a área normal de uma fileira ou a matriz ampliada de três fileiras
do servidor; uma edição de preset da Wheel no cliente não ativa o aprimoramento.
É necessário carregar o script atualizado no servidor e reabrir os clientes.

## Prioridade de magias e runas no Shooter

A cada oportunidade de ataque, o Shooter verifica as magias desde a primeira
prioridade configurada. Se a primeira terminou o cooldown, ela volta a ser
escolhida antes das seguintes; a lista não continua automaticamente da última
posição usada. Mana, quantidade mínima de criaturas, alcance, habilitação e
cooldowns individuais e dos grupos continuam sendo respeitados.

As runas são uma segunda opção, com prioridades próprias. Entram quando nenhuma
magia elegível está disponível, por exemplo quando todas estão em cooldown.
Uma runa com prioridade 1 não passa à frente de uma magia disponível com
prioridade 5. No Party Hunt, uma magia pronta aguardando posição ou direção
confirmada também impede que uma runa ocupe seu cooldown de ataque. O modo
explícito Always Run continua usando somente runas, sem posicionar para magias.

O movimento do Party Hunt consulta essa mesma ordem: a prioridade recuperada
substitui a anterior no planejamento da próxima posição.

## Prioridade das hotkeys manuais

Hotkeys de magia e uso manual de itens, pela Action Bar ou pelo gerenciador
antigo, reservam 750 ms antes de o Helper voltar a lançar magias automáticas.
Pressionar ou manter a tecla renova essa janela, inclusive quando o cliente
limita a repetição. O Shooter não reposiciona para uma magia automática nesse
intervalo. Cura por magia, Sio, haste, treino de mana e magias de passagem também
aguardam. Ao usar uma hotkey de item, poções automáticas também aguardam;
uma hotkey de magia mantém as poções de vida disponíveis. Chat comum e edição
de texto não suspendem o Helper. Os cooldowns do servidor continuam valendo.

O destino é mantido até mudar a próxima magia, a posição do líder ou surgir um
obstáculo. Se um SQM da formação estiver ocupado, procura outro lado livre e
alcançável; se todos os lados na distância pedida estiverem bloqueados, usa a
posição cardinal livre mais próxima e volta à distância desejada quando abrir
espaço. Não entra no SQM do líder ou de um monstro para cumprir uma distância.
Durante cooldowns mantém o lugar e olha para a box. O Shooter aguarda
posição e direção confirmadas antes da onda. Ultimates usam sua área circular;
Ulus usa sua área em anel. Essas magias não recebem a área de uma onda direcional.

Ao atingir a quantidade de atacantes escolhida, contorna a box entre três e cinco SQMs e
reserva pausas curtas após passos confirmados para virar e atacar, mesmo com
monstros encostados. Quando há uma magia pronta, procura sua distância de
lançamento no contorno, respeitando o mínimo de três SQMs durante a fuga.
Não abandona a box para manter a distância de cada monstro. Cobertura real,
mínimo de inimigos e cooldowns continuam valendo. Always run não para para
magias ofensivas e mantém o uso das runas.
Knight/Elite Knight não têm essas opções.

## Formação de Paladin / Royal Paladin

Cada Paladin escolhe sua própria opção **Paladin position** em Extras:

- **Close to box**: mantém dois SQMs entre personagens: EK, um SQM intermediário,
  RP. Busca um espaço livre nessa distância; não entra no SQM do líder nem dos
  monstros. Se a formação estiver bloqueada, procura outro espaço seguro próximo.
- **2 SQMs from leader**: mantém um espaço livre a dois SQMs do líder.
- **Circle and attack**: contorna a box visível no sentido horário, normalmente
  entre três e cinco SQMs, com pausas curtas após os passos confirmados para
  atacar pelo Shooter. Obstáculos podem exigir um desvio temporário no outro sentido.

`exevo mas san` é uma exceção nos três modos. Somente quando a magia está pronta
na rotação real, busca uma posição livre exatamente a **dois SQMs**, ao norte,
sul, leste ou oeste do líder. O Shooter lança a magia respeitando sua área real
e o mínimo de inimigos configurado; depois retoma o modo escolhido. Não lança
a partir de uma posição diagonal ou a outra distância quando os quatro lados
estão bloqueados. No modo de contorno, continua circulando enquanto aguarda espaço.

As demais magias usam o alvo real do Helper, sua distância de alcance, linha de
visão, mana e cooldown individual e de grupos. Magias centradas no alvo, como
`exevo tempo mas san`, continuam usando sua própria área, sem receber a regra
do Mas San centrado no personagem. O Party Hunt não cria uma segunda rotação
nem lança ataques por conta própria.

O limite **Run from (monsters)** também vale nos modos parados: ao atingir o
número escolhido de atacantes que causaram dano, começa a contornar a box sem
parar de atacar. Abaixo desse limite, retoma a posição selecionada. O modo
Circle and attack substitui para Paladin a opção Always run (runes); ele permite
magias e as runas configuradas no Helper. As preferências são pessoais,
validadas e persistidas no KV existente do personagem no servidor, sem nova tabela
ou migração de banco de dados.

## Escadas e recuperação

Com Party Hunt ativo, o servidor resgata automaticamente o membro quando ele
fica em outro andar, a mais de dez SQMs do líder ou sem linha de visão por
três segundos. Essa espera permite ao cliente primeiro contornar a parede.
O limite de dez SQMs vale para todas as vocações e conta também diagonais.
A exatamente dez SQMs, com visão livre, acompanha andando. Esse limite de
resgate é independente da distância usada para se posicionar ou contornar a box.
A recuperação coloca cada
membro em um SQM livre a exatamente três SQMs (distância de Chebyshev) do líder,
priorizando norte, sul, leste ou oeste e procurando outros pontos desse anel
quando necessário. Nunca move o líder, empilha membros ou usa tiles com criaturas,
mudança de andar, teleport, sem chão, sem visão da box ou rejeitados por `Tile:queryAdd`.

Sem espaço seguro, aguarda e tenta de novo a cada dois segundos. Cada recuperação
confirmada informa um novo serial ao cliente, que descarta o caminho e a formação
antigos. A sessão precisa estar ativa, com party válida de até quatro pessoas,
líder ativo e tempo disponível do membro. Stop, quota esgotada ou sair da party
desabilitam o resgate. A pausa individual também desabilita o resgate. Não existe botão de teleporte manual. PvP lock ou skull em qualquer participante encerra o grupo.

O servidor observa mudanças de andar do líder, inclusive andando manualmente,
e transmite um histórico curto das passagens. O cliente registra entrada e
direção da mudança e pode aproveitar Stair/Hur de uma rota do Cavebot, quando
disponível. Os membros seguem essas passagens conhecidas.

As passagens de `exani hur "up`, `exani hur "down`, `exani tera`, corda e
escadas clicáveis são registradas após a ação real ter sucesso no servidor.
Isso evita confundir uma magia com um passo comum. Um passo de escada pode
atravessar um SQM sem chão no andar atual somente na passagem registrada.
Passos cancelados e magias rejeitadas são repetidos sem trocar a passagem até
a confirmação de mudança de andar. Magias respeitam intervalos de 2,2 segundos;
o personagem precisa ter mana, nível e os demais requisitos normais da magia.
O histórico é mantido durante a sessão, incluindo membros atrasados.

Se um membro cair ou descer acidentalmente, procura uma passagem de retorno perto
da mudança observada. Depois, evita pisar novamente no ponto aprendido.
Sem passagem conhecida e alcançável, aguarda em vez de escolher buraco aleatório.
Levitação é uma ação de navegação, não um ataque do Party Hunt.

## Tempo e controle

Durante os testes, cada participante ativo tem **três horas** diárias persistidas
no servidor, na tabela
`party_hunt_usage`. Relogar não recupera tempo; server save reinicia a cota.
O Cavebot também tem três horas por ciclo, persistidas em `cavebot_usage`.
Os segundos já usados permanecem descontados: aumentar a cota não apaga o histórico.
Heartbeat expirado, sair da party, trocar líder, ultrapassar quatro pessoas,
esgotar cota ou Stop do líder interrompem o acompanhamento.
O modo de perseguir alvo é suspenso nos membros enquanto acompanham e restaurado
ao parar. Um membro pausado não acompanha, não é teleportado e permanece na party; Resume Party Hunt retoma o movimento. A pausa também consome tempo da sessão.

## Validação

Os testes Lua de cliente e servidor cobrem ativação sem Cavebot, controles,
janela automática, restauração, áreas de magia, cooldowns, pressão, sentidos
do contorno, limites, mudanças de andar, tempo persistente e teleport.
O comportamento completo durante uma hunt real ainda precisa ser avaliado
com os clientes da party conectados.

## Controles e alavancas (outubro de 2026)

Party Hunt: pausa individual e alavancas

O botão manual Teleport to leader foi removido do painel e o servidor rejeita o opcode antigo. A recuperação automática continua pelas regras existentes de distância/andar/visibilidade, com limite horizontal de 10 SQMs.

Na janela minimizada, o líder mantém Stop Party Hunt para encerrar o grupo. Os membros usam Stop Party Hunt para pausar apenas seu próprio acompanhamento e Resume Party Hunt para retomar. A pausa permanece na sessão do servidor: atualizações da janela, novos Starts do líder e formação de alavanca não retomam o membro. Não há movimento automático nem rescue enquanto pausado. O membro permanece na party. A cota diária continua sendo contabilizada enquanto a sessão está ativa, incluindo a pausa.

Qualquer participante com PZ lock por PvP ou skull impede o início e encerra uma sessão em andamento, antes do rescue. Uma protection zone normal não é motivo de parada. Desconexão/logout ou morte do líder aplica Stop ao Party Hunt de todos os participantes; o sistema não desfaz a party. Stop manual, limite de quatro participantes, fim da cota diária e perda de heartbeat continuam como controles de segurança.

A opção Boss lever e o botão Set hotkey aparecem apenas para o líder na janela flutuante/minimizada. Com Party Hunt ativo, o líder se posiciona no primeiro SQM, vira para a direção dos demais SQMs (north/east/south/west) e marca a opção ou pressiona a hotkey. O servidor captura posição, direção e ordem real da party; slots 2, 3 e 4 são um, dois e três SQMs nessa direção. Os membros chegam andando por espaços livres e permanecem nos próprios slots. Não se reposicionam para magias ofensivas durante a fila; a cura permanece com o Helper. Membros pausados não são movimentados.

Nos encontros iniciados por BossLever e no hub de mini-bosses, membros que chegaram
pelo resgate do Party Hunt recebem o cooldown no primeiro dano positivo ao boss.
O horário de liberação é o mesmo registrado na entrada original; hits posteriores
não renovam o prazo. Dano de summons conta para o dono, e fases de bosses de recompensa
na mesma arena usam a chave da alavanca. Cura, dano zero, criaturas comuns e ataques
de fora da arena não registram esse cooldown. O resgate bloqueia quem já tinha um
cooldown de outra tentativa; participantes daquele encontro continuam podendo ser resgatados.
A fila é opcional quando a alavanca aceita somente o líder: quantidade mínima e
demais exigências da alavanca continuam valendo. Usa o KV de cooldown existente,
sem nova tabela ou alteração de banco.

A opção desmarca ao utilizar uma alavanca do sistema BossLever ou quando o líder sair da posição (incluindo teleportes de outras alavancas). Se a entrada do boss for recusada, marque novamente para remontar a fila. A hotkey usa o editor existente do cliente, com persistência por preset/chat mode e tratamento de teclas conflitantes.

Validação: testes Lua de controle/UI, contrato do servidor, posições da fila nas quatro direções, pausa e retomada, regras de PvP, parada sem desfazer a party, recuperação de andar, Shooter e formação das vocações. QA nativa valida o layout real e o registro da hotkey em perfil isolado, sem login.
