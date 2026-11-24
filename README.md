# Michael Jackson: Journey of the King

## História e objetivo

Michael percorre cenários inspirados em suas músicas para recuperar fragmentos de memória. Uma presença conhecida como The Silence ameaça apagar essas lembranças. O objetivo da jornada é reunir os fragmentos, superar os obstáculos e seguir de uma fase à outra.

## Fases planejadas

- **Billie Jean** abre a jornada e apresenta os primeiros fragmentos de memória.
- **Thriller** leva Michael a um cenário de suspense.
- **Smooth Criminal** continua a busca em um ambiente inspirado na música e na coreografia.

## Personagens e habilidades

**Michael Jackson** é o protagonista. Usa um chute de dança contra inimigos próximos, lança o chapéu como um bumerangue e executa um moonwalk para deslizar para trás e esquivar de ataques.

**The Silence** é a presença que ameaça as memórias ao longo da jornada.

## Testes automatizados de jogabilidade

Na raiz do projeto, com a Godot 4.7.2:

```bash
godot --headless --editor --import
godot --headless --fixed-fps 60 --script res://Tests/gameplay_headless.gd
```

A suíte valida a progressão de Billie Jean até o retorno ao menu em Smooth Criminal. Ela usa as cenas do jogo, simula comandos, verifica trajetos contra as colisões reais e posiciona Michael em pontos de interesse. Para reproduzir as transições dos chefes e das ondas, aplica dano controlado pela interface de combate.

- **Billie Jean:** 57 pisos das três cotas, dois pisos removidos sob o relógio, encontros, barreiras, notas e indicador, aviso do fotógrafo e menu F1.
- **Thriller:** cinco ondas, três fases do Guardião, avisos de carga e onda, esquiva perfeita, colisão da carga com parede, reforços, barra de vida, desbloqueio do espelho, notas e cura.
- **Smooth Criminal:** notas, energia, portões, segurança, três etapas do chefe, reforços, HUD, espelho e retorno ao menu.
- **Controles e combate:** caminhada, dash, moonwalk, combo de três chutes, atordoamento, dano do chapéu na ida e na volta, figurino durante o voo e remoção dos inimigos derrotados.

Ainda é necessário avaliar em uma partida com renderização a oclusão das notas, a nitidez da pixel art, a legibilidade da rotação do chapéu e dos avisos e o equilíbrio dos encontros sem posicionamento ou dano controlado.
