# Escadas e cordas no Cavebot

Os controles ficam em **Record Waypoints**, incluindo nas janelas flutuantes.

- **Stair:** grave o ponto de execução e a direção do passo para a escada. O
  Cavebot só avança após confirmar a mudança de andar. Se o passo falhar ou
  apenas deslocar o personagem no mesmo andar, retorna ao ponto e tenta novamente.
  **Center** continua servindo como ponto de aproximação; se esse ponto for uma
  escada identificada no mapa, o personagem sai para um SQM livre e entra novamente
  quando a transição falhar. Escadas elevadas podem exigir um passo para uma
  posição sem chão visível, autorizado somente por esse waypoint explícito.
- **Rope:** grave a posição de onde usar a corda e selecione a direção do rope
  spot, ou **Center** quando estiver em cima dele. Usa Rope ou Elvenhair Rope do
  inventário, inclusive em backpack fechada. Não usa cordas largadas no chão.
- **Exani Tera:** grave o waypoint em cima do rope spot. Esse botão usa sempre
  **Center**, independentemente da direção selecionada. Verifica vocação, nível,
  premium, mana e cooldown antes de lançar a magia.
- **Hur Up / Hur Down:** mantenha uma direção cardinal. A execução continua
  esperando o fim do combate; uma tentativa não confirmada é repetida em vez de
  descartar o waypoint. Up e as cordas exigem chegada um andar acima; Down exige
  chegada um andar abaixo.

As ações aguardam a confirmação por 2,6 segundos antes de permitir nova tentativa.
Um waypoint de transição bloqueado permanece ativo até funcionar ou o jogador
interromper o Cavebot. Falta de mana, cooldown ou passagem ocupada não faz o bot
avançar indevidamente. As prioridades de cura e hotkeys manuais continuam valendo.

Os dois novos tipos são preservados nas configurações e nos arquivos JSON de rotas.
Clientes antigos não reconhecem esses tipos; use o cliente atualizado para carregar
rotas com Rope e Exani Tera.

Validação: `tests/lua/cavebot_transitions_spec.lua` cobre tentativas repetidas,
retorno ao ponto, escada sem sinalização, reentrada de escada central, saída de
escada elevada, cordas, Levitate e persistência. `helper_shooter_lure_spec.lua`
valida os envios reais de magia/item, cooldowns e as duas cordas.
`tests/native/cavebot_transitions.lua` verifica o layout real nas duas janelas.
