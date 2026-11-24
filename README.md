# Michael Jackson: Journey of the King

Jogo 2D de ação e aventura em pixel art, com visão de cima em três quartos. Michael percorre cenários inspirados em suas músicas para recuperar suas memórias.

## História

No camarim, Michael descobre que uma presença chamada **The Silence** ameaça apagar suas lembranças. O espelho dá acesso a mundos formados por essas memórias. Cada lugar guarda algo que Michael precisa restaurar para seguir adiante.

## Objetivo do jogador

Atravesse as quatro fases, supere os obstáculos, recupere as memórias e derrote The Silence. Explore os cenários para coletar notas musicais e encontrar itens de recuperação.

## Fases

| Fase | Como avançar |
| --- | --- |
| **Billie Jean** | Acenda pisos luminosos nas três regiões e enfrente os detetives para restaurar o relógio, a jukebox e a fonte. |
| **Thriller** | Atravesse o cemitério, vença as ondas de zumbis e derrote o Guardião do Espelho e seus reforços. |
| **Smooth Criminal** | Restaure a energia do clube dos anos 1930, use a cobertura contra os holofotes, abra o acesso VIP e derrote a segurança e o líder dos capangas. |
| **O Último Eco** | Enfrente The Silence em uma arena que reúne fragmentos das três memórias anteriores. |

### The Silence

| Etapa | Ataque e mudança na arena |
| --- | --- |
| **Apagamento** | O chefe anuncia uma onda circular. Os relicários estão apagados. |
| **Fratura** | Uma fenda marca a posição de Michael antes de atingir a área. O piso ganha luz azul e o primeiro relicário é restaurado. |
| **Último eco** | O chefe alterna fendas e investidas anunciadas. O piso ganha luz roxa e o segundo relicário é restaurado. |

Aproveite a abertura após cada ataque para usar chutes e o chapéu. Uma esquiva perfeita pode prolongar essa janela. Na vitória, os pisos ficam dourados, o último relicário e o portal são restaurados e a arena recebe ondas e partículas de restauração.

## Personagens e inimigos

- **Michael Jackson** é o protagonista. Luta com chutes de dança, um chapéu que volta como um bumerangue e o moonwalk.
- **The Silence** é a entidade que ameaça as memórias e o chefe de O Último Eco.
- **Detetives, zumbis e capangas** têm ritmos, alcances e resistências diferentes. O fotógrafo anuncia o flash. O Guardião do Espelho e o líder dos capangas mudam de comportamento ao longo dos confrontos.

## Controles e habilidades

| Entrada | Ação |
| --- | --- |
| **WASD** ou **setas** | Mover Michael |
| **Botão esquerdo do mouse** | Chutar na direção do cursor. Três chutes em sequência ativam o golpe final. |
| **Espaço** | Lançar o chapéu |
| **Ctrl esquerdo** | Fazer dash na direção do movimento |
| **Shift** | Deslizar para trás com moonwalk. O tempo certo permite uma esquiva perfeita. |
| **E** | Interagir com objetos e espelhos |
| **Esc** | Pausar ou retomar |
| **F1** | Abrir o menu de desenvolvimento na execução pelo editor |

## Coletáveis

Cada **nota musical** vale 100 pontos. O HUD acompanha as notas e a pontuação da fase. Billie Jean e Thriller têm setas para notas próximas fora da tela, que somem nos encontros obrigatórios. Os itens de **cura** recuperam um coração quando Michael está ferido.

## Vitória e derrota

Restaure os pontos de memória e vença os encontros obrigatórios para liberar as passagens. Os espelhos permitem continuar a jornada. Após derrotar The Silence, atravesse o portal restaurado para ver o desfecho.

Michael é derrotado quando perde os quatro corações. A tela de derrota abre depois da animação e permite tentar novamente ou voltar ao menu.

## Três tentativas

Cada fase começa com três tentativas e cada tentativa começa com quatro corações. A primeira derrota deixa duas tentativas e a segunda deixa uma. Na terceira, o Game Over oferece a opção de recomeçar a fase com três novas tentativas. Repetir a tentativa mantém o saldo. Entrar em outra fase restaura as três tentativas. O Camarim fica fora dessa contagem.

## Progressão e dificuldade

Billie Jean apresenta exploração e encontros locais. Thriller pede atenção aos avisos de ataque e à ordem das ondas. Smooth Criminal combina combate com vigilância e cobertura. O Último Eco reúne essas habilidades em um confronto com janelas de contra-ataque.

## Direção artística

As fases usam pixel art com filtro **Nearest**, materiais e silhuetas inspirados nos videoclipes. O Último Eco mistura pedra, madeira, calçadas, motivos góticos e detalhes art déco. Os quatro estados da arena compartilham a geometria e mudam a iluminação do piso e dos objetos.

As três versões de The Silence usam quadros de 64×64, pivô em `[32, 56]` e escala 2×. Cada versão tem 29 animações e 92 referências de quadros. Repouso, movimento, preparação, ataque, impacto, vulnerabilidade e mudança de etapa usam quatro direções. A derrota é frontal e termina com um quadro transparente para a dispersão.

## Tecnologias e organização

Abra `project.godot` na **Godot 4.7.2**. O jogo usa GDScript, TileMapLayer, colisões 2D e SpriteFrames.

- `Assets/UltimoEco/Tiles/` contém o atlas de piso de 32×32. Os TileSets das arenas estão nas próprias cenas.
- `Assets/UltimoEco/Boss/`, `Efeitos/` e `Objetos/` contêm as spritesheets, animações e texturas da fase. Os efeitos usam quadros de 128×128. A procedência dos recursos de O Último Eco está em `Assets/UltimoEco/producao.json`.
- `Scenes/ArenasUltimoEco/` contém as três etapas da arena e o estado restaurado. `Scenes/ultimo_eco.tscn` reúne os recursos, e seus scripts em `Scripts/` controlam a luta, a navegação e as colisões.
- `Scenes/` reúne as cenas jogáveis e as interfaces. `Scripts/` contém as regras de progressão, combate e interface.

## Créditos

- **Mateus** — Arte & Sprites.
- **Luan** — Programação & Design.
