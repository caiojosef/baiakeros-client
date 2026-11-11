# Rashid: raridades e Sell All

Correção de 06/11/2026 para o MMO Canary/OTC. Trabalho separado do Idler.

Rashid aceita equipamentos Common, Rare, Epic e Ultra que já fazem parte de seu catálogo. O preço é o mesmo do item normal, sem multiplicador de raridade. A contagem enviada ao cliente e a remoção usam a mesma elegibilidade. Forge, imbuements ativos, propriedade/store e estado inválido de charges/duration continuam protegidos; containers com conteúdo não são vendidos como item vazio. Blacklist e Ignore Equipped continuam valendo no cliente.

A exceção de raridade é exclusiva do Rashid. O mercado de commodities continua rejeitando itens com raridade, pois não preserva atributos por instância. A alteração parcial que já existia no Quente foi preservada no histórico antes de completar a correção.

Cada pedido de venda ao Rashid devolve a contagem atualizada de mercadorias, inclusive quando uma exaustão rejeita o pedido. O Sell All espera uma redução confirmada na quantidade antes de descontar o lote. Vendas parciais continuam no mesmo tipo de item; pedidos rejeitados são repetidos com espera. Ao final, o cliente confere os itens restantes. Após três tentativas sem progresso por item, encerra com uma mensagem que informa a sobra, sem loop infinito ou confirmação falsa.

O cliente também deixa de descontar novamente equipamentos com Forge que já foram excluídos da contagem pelo servidor. A fila compartilhada atende às interfaces moderna e legacy, com cancelamento e invalidação de callbacks ao fechar/trocar de loja. Nenhuma proteção extra por raridade ou confirmação adicional foi adicionada.

Validação: compilação Linux release; testes de fila com 100 itens, rejeição, remoção parcial, atraso, limites de lote, blacklist, equipamentos, cancelamento e falta de resposta. Testes com cliente nativo e conta descartável passaram com 100 itens mistos e, depois, 100 itens exclusivamente Common/Rare/Epic/Ultra, a 90.000 gold cada, preservando um Ultra equipado e um Ultra com Forge. O segundo teste usa o catálogo real antes da loja abrir, verifica a consulta padrão e a consulta explícita com raridades e confirma a inclusão de um tipo que não tem nenhuma cópia normal.

Esta branch usa a base publicada r43. As chances de loot do Quente não fazem parte da correção: o teste de chances reduzidas fica na branch separada dudantas/rarity-low-drops-local-20261105. A configuração localhost, start.sh, recompile.sh, mapas e dados de jogadores não entram no commit.

## Publicação verificada em 06/11/2026

Fonte do executável do Quente: `66964ea4f8a5b73770f6acbefc6afe671fe86be6`. Compilação nativa e reinício do serviço canary concluídos; portas 7171/7172 e logs de inicialização verificados. SHA-256 do executável: `bb5dad7057acd7762a2346bc656e167a85dc96399d528936fe05e6b789a76d89`.

Cliente/assets na revisão 44, fonte `336cc2eae5fd2d7639f60a0431265756c0516cd1`. Quatro pacotes alterados (init.lua gerado e três arquivos Lua da interface de trade), 16.332 arquivos preservados e nenhuma exclusão. Tamanho e hashes compactados/descompactados dos pacotes públicos passaram por HTTPS; o teste real do launcher TestPublishedNativePackages passou. O executável do OTC foi reutilizado porque esta correção do cliente é Lua.

O catálogo de abertura consulta explicitamente as raridades antes de existir shopOwner. A binding player:getAllSaleItems aceita um booleano opcional, sem mudar o ciclo de vida/ownership do userdata. Consultas e mercado continuam com seus padrões; somente o fluxo do Rashid pede a exceção.

Backup remoto: /var/backups/baiakeros/rashid-r44-20261106, incluindo o código anterior, alterações não commitadas preservadas em stash, definição do serviço, manifestos e nginx. start.sh, recompile.sh, config.lua, market.local.lua e as chances publicadas de item_rarity.lua tiveram seus hashes preservados. A reversão restaura também a alteração parcial que já existia no Quente.

Os dados e credenciais das contas descartáveis foram removidos. O helper de QA permanece somente em tools/local-test, fora do autoload. Mapas e dados de jogadores não foram substituídos. A WSL mantém o experimento separado de chances menores; essa alteração não foi levada ao Quente nesta publicação.

PRs: https://github.com/caiojosef/baiakeros/pull/18 e https://github.com/caiojosef/baiakeros-client/pull/22. Merge na main depende de revisão e solicitação. Fechar o OTC e abrir pelo launcher para receber a revisão 44.
