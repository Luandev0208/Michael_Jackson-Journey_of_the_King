# O Último Eco — recursos visuais

Este documento descreve o pacote original. O jogo usa os recursos de execução em `res://the_silence/`. O pacote ZIP também inclui prévias, folhas de poses, layouts JSON, recursos de edição e arquivos de validação. A fase jogável está em `res://Scenes/ultimo_eco.tscn`.

Arena original com pedra, madeira, calçadas e pisos de memória. Os materiais derivam de tiles individuais dos pacotes anteriores; os obstáculos fundem motivos góticos e art déco. Não foram coladas imagens completas das fases. Nenhum sprite de Michael foi redesenhado.

## Conteúdo e montagem

- `the_silence_tileset.png` e `.tres`: **108 tiles de 32×32**. Quatro materiais com variações, 64 transições, quatro estados luminosos, bordas do vazio e detalhes de chão.
- `the_silence_objetos.png` e `objetos/`: oito estruturas principais, seis peças de oclusão e seis estados apagado/restaurado; **20 PNGs individuais**.
- `boss/`: três spritesheets, SpriteFrames, JSONs, folha de poses ampliada por Nearest e GIF de demonstração.
- `efeitos/`: oito animações, **50 quadros de 128×128**, SpriteFrames e PNGs individuais do primeiro quadro de cada efeito. Os efeitos completos estão na spritesheet.
- Quatro layouts JSON, quatro cenas `.tscn` e quatro prévias PNG: `fase_1`, `fase_2`, `fase_3` e `restaurada`. `the_silence_preview.png` mostra a terceira etapa; `quatro_estados.png` compara os estados.
- `validacao/`: resultados dos testes e hashes dos arquivos.

Copie a pasta **the_silence** para `res://the_silence/`. Abra uma das cenas `arena_*.tscn` ou use o TileSet em TileMapLayer. Preserve a estrutura dos arquivos. Não há scripts de gameplay, colisões, navegação, áudio, diálogos ou cutscene nessas cenas. A geometria do chão está conectada; as áreas de circulação ainda precisam ser testadas com as colisões reais do jogo.

Use filtro **Nearest** e coordenadas inteiras. Atlas sem suavização; transparência binária nos personagens e objetos. Os efeitos usam níveis discretos de alpha intencionais, não bordas suavizadas. As transições de terreno usam cantos **NW=1, NE=2, SW=4, SE=8**; escolha a máscara pelo JSON. O TileSet não configura pintura automática de Terrain Sets nem colisões.

Os objetos têm origem no apoio indicado por `pivot`. Em um Node2D no apoio, deixe Sprite2D sem centralização e aplique `position=-pivot`; use Y Sort no grupo. Para obelisco, poste e portal, use a peça inteira OU `_base` + `_alto` com a mesma origem. Os dois recortes recompõem exatamente a imagem original; ajuste a camada superior à oclusão desejada.

## The Silence

**Células 64×64**, pivô `[32,56]`, corpo neutro com aproximadamente 36 pixels de altura; escala sugerida 2×, compatível com o padrão das referências. A célula maior reserva espaço para os braços e a dispersão. O sprite flutua um pixel durante repouso/vulnerabilidade. As três versões compartilham geometria, quadros, pivôs e nomes; somente os detalhes luminosos mudam de cor/intensidade.

| Animação | Quadros | Direções | Loop |
|---|---:|---|---|
| `idle_*` | 2 | down/up/left/right | sim |
| `move_*` | 4 | down/up/left/right | sim |
| `prepare_*` | 3 | down/up/left/right | não |
| `attack_*` | 4 | down/up/left/right | não |
| `hurt_*` | 2 | down/up/left/right | não |
| `vulnerable_*` | 2 | down/up/left/right | sim |
| `phase_change_*` | 4 | down/up/left/right | não |
| `death` | 8 | frontal | não |

Cada versão tem **29 animações e 92 referências de quadros**. São 32 poses-base geradas, com movimentos de pernas, antecipação, braços estendidos, recuo, ajoelhar e transformação distintos. Esperas repetem poses; repouso usa deslocamento de um pixel. Não são 92 desenhos exclusivos nem ciclos longos desenhados manualmente. A derrota combina recuo, ajoelhamento e dispersão dos pixels do corpo. **O último quadro de `death` é completamente transparente por intenção**, para que The Silence desapareça definitivamente; não é erro de recorte. Não há derrota em quatro direções.

## Três etapas — contrato visual para integração futura

| Etapa | Recurso do chefe | Ambiente e efeitos disponíveis |
|---|---|---|
| 1 — Apagamento | `the_silence_fase_1.tres` | Pisos apagados, relicários escuros, ondas de silêncio. |
| 2 — Fratura | `the_silence_fase_2.tres` | Pisos azuis, primeiro relicário restaurado, aviso circular e fendas. |
| 3 — Último eco | `the_silence_fase_3.tres` | Pisos roxos, dois relicários restaurados, mudança de fase e vulnerabilidade. |
| Encerramento | `death`, sem loop | Terceiro relicário e portal restaurados, pisos dourados, onda e partículas de restauração. |

Essa tabela propõe a associação dos recursos; não implementa transições, gatilhos de vida, invulnerabilidade, dano, vitória nem encerramento narrativo. O Codex deverá conectá-los aos sistemas existentes. Os estados finais permitem mostrar visualmente a vitória, sem cutscene.

## Efeitos independentes

Todos usam células 128×128 e pivô `[64,64]`: `onda_silencio` (8), `onda_restauracao` (8), `aviso_circular` (4), `perigo_circular` (4), `fenda_energia` (6), `fragmentos_memoria` (8), `restauracao_particulas` (8), `nevoa` (4). Aviso, perigo e névoa repetem; os demais terminam. Os JSONs registram FPS e coordenadas. Os marcadores são gráficos: seus limites não definem automaticamente áreas de dano. Mantenha-os independentes do piso e dos objetos.

## Validação e limites

Testados PNGs, alpha, células, coordenadas, margens, equivalência geométrica entre fases, encaixes de bordas/transições e recomposição dos objetos separados. As quatro prévias foram reconstruídas a partir dos arquivos entregues e comparadas pixel a pixel. `borda_vazio_00` é um tile transparente intencional.

Teste executado na **Godot 4.7.2-stable oficial**, em modo headless: importação, 108 tiles, três SpriteFrames do chefe, 87 animações/276 referências, oito animações de efeitos, 95 instâncias reproduzindo animações e quatro cenas salvas/reabertas. Isso não equivale a testar combate, dificuldade, colisões ou integração no jogo original. Não houve alteração no GitHub nem nos scripts do projeto.

Os recursos foram produzidos por geração de imagem, com recorte, paleta compartilhada, alinhamento e empacotamento programáticos. Os prompts e a procedência estão em `producao.json`. A redução para a escala do jogo descarta detalhes finos da arte original; revise os GIFs e a folha de poses ao integrar.
