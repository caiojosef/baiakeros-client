# Rashid: raridades e Sell All

Correção de 06/11/2026 para o MMO Canary/OTC. Trabalho separado do Idler.

Rashid aceita equipamentos Common, Rare, Epic e Ultra que já fazem parte de seu catálogo. O preço é o mesmo do item normal, sem multiplicador de raridade. A contagem enviada ao cliente e a remoção usam a mesma elegibilidade. Forge, imbuements ativos, propriedade/store e estado inválido de charges/duration continuam protegidos; containers com conteúdo não são vendidos como item vazio. Blacklist e Ignore Equipped continuam valendo no cliente.

A exceção de raridade é exclusiva do Rashid. O mercado de commodities continua rejeitando itens com raridade, pois não preserva atributos por instância. A alteração parcial que já existia no Quente foi preservada no histórico antes de completar a correção.

Cada pedido de venda ao Rashid devolve a contagem atualizada de mercadorias, inclusive quando uma exaustão rejeita o pedido. O Sell All espera uma redução confirmada na quantidade antes de descontar o lote. Vendas parciais continuam no mesmo tipo de item; pedidos rejeitados são repetidos com espera. Ao final, o cliente confere os itens restantes. Após três tentativas sem progresso por item, encerra com uma mensagem que informa a sobra, sem loop infinito ou confirmação falsa.

O cliente também deixa de descontar novamente equipamentos com Forge que já foram excluídos da contagem pelo servidor. A fila compartilhada atende às interfaces moderna e legacy, com cancelamento e invalidação de callbacks ao fechar/trocar de loja. Nenhuma proteção extra por raridade ou confirmação adicional foi adicionada.

Validação: compilação Linux release; testes de fila com 100 itens, rejeição, remoção parcial, atraso, limites de lote, blacklist, equipamentos, cancelamento e falta de resposta. Teste com cliente nativo e conta descartável verifica 100 itens normais/Common/Rare/Epic/Ultra a 90.000 gold cada, preservando um Ultra equipado e um item Forge.

Esta branch usa a base publicada r43. As chances de loot do Quente não fazem parte da correção: o teste de chances reduzidas fica na branch separada dudantas/rarity-low-drops-local-20261105. A configuração localhost, start.sh, recompile.sh, mapas e dados de jogadores não entram no commit.
