# Party Hunt: acompanhamento, Druid e Sorcerer

O líder da party inicia Party Hunt. Pode andar manualmente ou usar Cavebot:
os controles são independentes. Os membros com o cliente atualizado acompanham
automaticamente, sem abrir o Helper. A party tem no máximo quatro personagens,
incluindo o líder; qualquer vocação pode liderar.

Start habilita Auto Attack e Enable Shooter Helper em todos os participantes.
Configure antes as magias, runas e cura no Helper. Os ataques são escolhidos
e executados pelo Helper, com preferência pelo alvo visível do líder.
Party Hunt movimenta os membros, sem mover o próprio líder.
Stop Party Hunt encerra o acompanhamento e restaura os controles anteriores
de cada participante. Stop no Cavebot não encerra Party Hunt.

## Janela e movimento compartilhado

Ao iniciar, todos recebem a janela reduzida com tempo restante e os quatro nomes,
com o líder primeiro. Back to Helper abre a aba Party Hunt; Expand mostra detalhes.
Somente o líder controla Start/Stop. Cada jogador configura suas próprias
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

O MS mantém três SQMs. As magias e os ataques continuam vindo do Shooter, não
de um lançador novo no Party Hunt. As áreas reais e o mínimo de inimigos
configurado no Helper continuam valendo: o movimento não falsifica a cobertura.

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
Outras vocações habilitadas têm acompanhamento e recuo; suas formações
específicas serão desenvolvidas depois. Knight/Elite Knight não têm essas opções.

## Escadas e recuperação

Com Party Hunt ativo, o servidor resgata automaticamente o membro quando ele
fica em outro andar, a mais de cinco SQMs do líder ou sem linha de visão por
três segundos. Essa espera permite ao cliente primeiro contornar a parede.
A recuperação coloca cada
membro em um SQM livre a exatamente três SQMs (distância de Chebyshev) do líder,
priorizando norte, sul, leste ou oeste e procurando outros pontos desse anel
quando necessário. Nunca move o líder, empilha membros ou usa tiles com criaturas,
mudança de andar, teleport, sem chão, sem visão da box ou rejeitados por `Tile:queryAdd`.

Sem espaço seguro, aguarda e tenta de novo a cada dois segundos. Cada recuperação
confirmada informa um novo serial ao cliente, que descarta o caminho e a formação
antigos. A sessão precisa estar ativa, com party válida de até quatro pessoas,
líder ativo e tempo disponível do membro. Stop, quota esgotada ou sair da party
desabilitam o resgate. Ele pode funcionar durante combate; o botão manual
Teleport to leader continua exigindo protection zone e cooldown de dez minutos.

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
ao parar. Teleport to leader mantém as regras: somente líder, todos em protection
zone e cooldown persistente de dez minutos.

## Validação

Os testes Lua de cliente e servidor cobrem ativação sem Cavebot, controles,
janela automática, restauração, áreas de magia, cooldowns, pressão, sentidos
do contorno, limites, mudanças de andar, tempo persistente e teleport.
O comportamento completo durante uma hunt real ainda precisa ser avaliado
com os clientes da party conectados.
