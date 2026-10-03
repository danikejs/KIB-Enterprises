# Ping Pong 2D — projeto Godot 0.7

Projeto jogável baseado no GDD da equipe, adaptado à referência visual enviada: praça em pixel art, câmera de cima, mesa central e personagens nas duas pontas. Testado com **Godot 4.4.1 Standard (GDScript)** em 2 de outubro de 2026. Renderer Compatibility; não exige .NET nem plugins.

## Abrir e jogar

1. Extraia o ZIP inteiro para uma pasta no computador.
2. Abra o gerenciador de projetos da Godot e clique em **Importar**.
3. Selecione o arquivo **project.godot** da pasta `PingPong_Godot`.
4. Aguarde a importação dos recursos e aperte **F5**.
5. Escolha **Como jogar**, **Partida rápida** ou **Jogar torneio**.

A arena e as telas são desenhadas/criadas pelos scripts durante a execução. Portanto, o editor 2D pode parecer vazio antes de apertar F5. O pacote contém o projeto-fonte; o editor Godot é necessário para executá-lo desta forma.

## Controles

| Entrada | Ação |
| --- | --- |
| A/D ou setas esquerda/direita | Mover a jogadora na parte inferior da mesa |
| Mouse | Movimento horizontal, quando selecionado em Opções |
| Espaço | Testar timing perfeito até 100 ms antes/depois do contato |
| Q / E, segurado ao rebater | Curvar a bola para a esquerda / direita |
| Shift | Armar a Bola de Incêndio com 100% de carga; apertar de novo cancela |
| Esc | Pausar/continuar a partida |
| F11 | Alternar janela e tela cheia |

A bola rebate automaticamente se tocar a raquete. Um timing perfeito acelera a bola e dá carga extra. A posição de contato determina o ângulo de saída. O movimento da raquete também aplica um pouco de efeito.

## O que o jogo inclui

- Menu inicial com demonstração animada, instruções, opções e créditos.
- Uma praça em pixel art, com mesa vista de cima, árvores, bancos e iluminação de fim de tarde.
- Dois personagens com poses de espera, deslocamento e rebatida; Hugo fica embaixo e o rival em cima.
- Bola com sombra, representação de altura e quique, rastros e efeitos de impacto.
- Partida rápida contra o primeiro rival.
- Torneio com quatro oponentes: Muralha (defensivo), Faísca (agressivo), Vértice (técnico) e Caos (imprevisível).
- Mapa de progressão, melhor de três sets, pontuação correta, saque automático e tela de resultados.
- Timing de ±100 ms, spin e uma bola especial de aceleração.
- Uma escolha entre três melhorias após cada vitória, antes da próxima partida.
- HUD com pontos, sets, contagem de trocas, timings perfeitos e carga especial.
- Pausa manual e automática quando a janela perde o foco.
- Trilha em loop e efeitos sonoros sintetizados para esta versão.
- Dificuldade, controle, meta de pontos e volume configuráveis. Opções e recorde salvos localmente em `user://settings.cfg`.

## Regras adotadas nesta versão

Estas são decisões de implementação para testar pontos que o GDD deixava em aberto:

- Movimento horizontal e rebatida por contato; Espaço concede bônus de precisão.
- A bola não rebate nas laterais da mesa: uma saída lateral dá o ponto ao adversário do último rebatedor.
- Partida em melhor de **três sets**: vence quem ganhar dois.
- Meta padrão de **7 pontos** por set, ajustável para 5 ou 11.
- São necessários dois pontos de vantagem, até o limite de **meta + 8**. Com meta 7, o set termina no máximo em 15.
- Rebatidas dão 12 de carga; timing perfeito dá mais 18; cada ponto dá 8. Carga máxima: 100.
- A Bola de Incêndio consome a carga no próximo contato e aumenta a velocidade em 32%, respeitando o teto. O efeito termina quando a CPU rebate.
- Cada vitória intermediária oferece uma melhoria gratuita: Reflexo de Ouro (+15 ms), Spin de Aço (+30% de efeito) ou Carga Rápida (+6 de carga por contato).
- Melhorias podem acumular e duram apenas a corrida. A derrota encerra o torneio. Não há moeda nem compra com dinheiro real.
- O cenário e os sprites foram gerados para este projeto com a ferramenta integrada de imagens. Os quatro estilos de CPU compartilham o mesmo sprite-base nesta versão. Nomes, identidade e áudio seguem provisórios. O nome do estúdio e os integrantes podem ser preenchidos na função `show_credits()`.

## Organização para editar

| Arquivo/nó | Responsabilidade |
| --- | --- |
| `main.tscn` | Cena principal com RegrasDaPartida, Arena2D, Audio e Interface |
| `main.gd` | Menu, HUD, opções, mapa, melhorias e fluxo das telas |
| `scripts/match_rules.gd` | Física da bola, adversários, pontuação, timing, spin e especial |
| `scripts/arena.gd` | Câmera de cima, mesa, atlas dos personagens, animações, bola e efeitos |
| `assets/art/park.png` | Cenário original da praça |
| `assets/art/players.png` | Atlas RGBA transparente: quatro colunas e duas linhas |
| `assets/art/ART_PROMPTS.md` | Especificação e prompts dos recursos visuais |
| `scripts/sound.gd` | Reprodução e volume da trilha/efeitos |
| `assets/audio/` | Arquivos WAV prontos para usar |
| `assets/icon.svg` | Ícone vetorial provisório do jogo |
| `tools/generate_audio.py` | Fonte opcional para regenerar o áudio; Python não é necessário para jogar |
| `tests/test_game.gd` | Verificações automatizadas das regras e navegação |
| `tests/capture_screens.gd` | Captura das telas pelo próprio motor |

A velocidade do jogador e o limite de velocidade da bola são exportados no nó RegrasDaPartida. A tabela `OPPONENTS` contém velocidade, reação, precisão, tamanho e cor de cada adversário. As telas são construídas em GDScript com controles nativos da Godot.

## Verificação

Foram executadas **56 verificações automatizadas**, todas aprovadas, com Godot 4.4.1. Cobrem pontuação nas duas saídas, colisões, frame prolongado, regras de set, timing antes/depois, consumo de especial, spin, limites de movimento, pausa, saque, melhorias, saídas laterais, transformação da câmera, controles horizontais e navegação até o final do torneio. Nesta revisão, as oito telas foram renderizadas em OpenGL Compatibility e conferidas visualmente. A suíte de 55 testes também passou na Godot 4.4.1.

Para repetir, tendo `godot` disponível no terminal dentro desta pasta:

```sh
godot --headless --editor --quit
godot --headless --script res://tests/test_game.gd
```

O teste usa as configurações locais do usuário e simula um torneio vencido, portanto altera o recorde local. O teste confirma funcionamento; a dificuldade e o ritmo ainda devem ser ajustados com jogadores.

Documentação de linha de comando da Godot: https://docs.godotengine.org/en/4.4/tutorials/editor/command_line_tutorial.html

## Edição dos sprites e da câmera

O atlas `players.png` tem 1536 × 1024 pixels: quatro células de 384 × 512 por linha. A linha superior contém Hugo visto de costas; a inferior, o rival visto de frente. As colunas representam espera, deslocamento à esquerda, deslocamento à direita e rebatida. O motor recorta e anima o atlas em tempo de execução; o PNG original mantém a transparência.

Para manter as regras independentes da câmera, `match_rules.gd` usa X lógico como profundidade e Y lógico como posição lateral. `court_to_screen()` converte esses eixos para a câmera vista de cima. Por isso, os identificadores internos `move_up` e `move_down` correspondem às ações visuais esquerda e direita nesta versão.

A meta é um arcade inspirado no clima da referência, com regras próprias. Ainda é recomendado jogar partidas reais para ajustar dificuldade, tempo das animações e intensidade dos efeitos.

## Alterações da versão 0.4

- Novo atlas de Hugo e rival com contornos em degraus e pixels aparentes; gerado com a ferramenta integrada de imagens.
- Passos alternados conforme a distância percorrida; arranque e freio curtos.
- Velocidade de saque: 680 + 45 por fase; a cada contato: velocidade × 1,12 + 18, até 1900.
- Trilha instrumental original em 96 BPM, loop de 40 segundos, piano, baixo e percussão. Volume da música aumentado. O volume geral salvo nas opções continua valendo.
- Retirados os textos promocionais sobre pixel art da tela inicial.
- Mantida a correção do conflito draw_ellipse.

## Visual da versão 0.6

Menu lateral compacto, painéis escuros discretos e fonte Pixelify Sans em todas as telas. Removidos o cartaz, a fonte serifada e as fichas de papel.

Personagens refeitos com o cenário como referência: verde sálvia e terracota, cores suaves, luz quente. Escala reduzida de 100 × 128 para 84 × 108, com sombras menores junto aos pés.

Fonte incluída em assets/fonts/pixel.ttf; licença OFL em PIXEL_FONT_LICENSE.txt. Prompt dos sprites em assets/art/PROMPT_V06.txt. As oito capturas em previews/ são desta versão. 55 testes passaram na Godot 4.4.1. Não foi testado com Godot 4.7.2 neste ambiente.

## Ajustes da versão 0.7 — vigentes

- Novo atlas de personagens com desenho simplificado. A renderização usa células nativas de 32 × 48 pixels e ampliação inteira de 3×, sem suavização (96 × 144 por pose).
- Personagens cerca de um terço mais altos que na versão 0.6; removidos os nomes repetidos junto aos sprites para evitar sobreposição.
- Movimento do jogador: 460 em vez de 740 unidades por segundo. Arranque em aproximadamente 92 ms, parada em aproximadamente 66 ms.
- Saque: 500 + 30 por fase. Rebatidas: velocidade × 1,06 + 8; teto 1200. Oito contatos normais levam de 500 a aproximadamente 876; golpes perfeitos e especiais têm seus próprios bônus.
- Mantidos menu, fonte pixel, cenário, trilha e torneio.
- 56 verificações aprovadas na Godot 4.4.1; capturas atualizadas. Sem teste na Godot 4.7.2.
- Novos sprites gerados com a ferramenta integrada de imagens; prompt em assets/art/PROMPT_V07.txt.
