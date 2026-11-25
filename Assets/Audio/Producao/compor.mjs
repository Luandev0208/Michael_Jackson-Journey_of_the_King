// Execute da raiz do projeto: node Assets/Audio/Producao/compor.mjs <ffmpeg>
// Opcionalmente, passe o nome de uma faixa sem extensão como segundo argumento.
// Sintetiza a partitura abaixo em PCM e codifica Ogg Vorbis. Nenhum sample externo.
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { join } from 'node:path';

const pastaAudio = fileURLToPath(new URL('../', import.meta.url));
const ffmpeg = process.argv[2] ?? 'ffmpeg';
const taxa = 48000;
const tau = Math.PI * 2;
const quadros = (segundos) => Math.round(segundos * taxa);
const hz = (midi) => 440 * 2 ** ((midi - 69) / 12);
const linear = (db) => 10 ** (db / 20);
const limitar = (x) => Math.max(0, Math.min(1, x));
const rampa = (x) => .5 - .5 * Math.cos(Math.PI * limitar(x));

function gerador(chave) {
  let estado = 2166136261;
  for (const letra of chave) estado = Math.imul(estado ^ letra.charCodeAt(0), 16777619);
  return () => {
    estado ^= estado << 13;
    estado ^= estado >>> 17;
    estado ^= estado << 5;
    return 2 * ((estado >>> 0) / 4294967296) - 1;
  };
}

// Ataque, soltura, nível de sustentação e tempo de decaimento.
const VOZES = {
  feltro: [.007, .22, .28, .72],
  rhodes: [.005, .18, .47, .8],
  vitral: [.004, .34, .12, .46],
  baixo: [.012, .085, .80, .26],
  baixo_curto: [.005, .115, .43, .21],
  contrabaixo: [.008, .14, .37, .24],
  cordas: [.15, .35, .83, .58],
  pad: [.21, .40, .80, .75],
  palheta: [.023, .10, .78, .24],
  metal: [.012, .09, .62, .18],
  pulso: [.018, .17, .76, .34],
  harpa: [.006, .19, .25, .27],
  coro: [.26, .34, .84, .78],
};

function parcial(p, f, t, v, noise) {
  const seno = Math.sin(p);
  switch (v) {
    case 'feltro':
      return .78 * seno + .24 * Math.sin(p * 2.003) * Math.exp(-3.6 * t)
        + .13 * Math.sin(p * 3.01) * Math.exp(-7.0 * t)
        + .07 * Math.sin(p * 5.02) * Math.exp(-17 * t) + .06 * noise * Math.exp(-86 * t);
    case 'rhodes':
      return .84 * Math.sin(p + .77 * Math.exp(-4.3 * t) * Math.sin(p * 1.998))
        + .19 * Math.sin(p * 3.997) * Math.exp(-16 * t);
    case 'vitral':
      return .74 * seno + .36 * Math.sin(p * 2.01) * Math.exp(-5 * t)
        + .17 * Math.sin(p * 2.78) * Math.exp(-8 * t) + .14 * Math.sin(p * 4.08) * Math.exp(-12 * t);
    case 'baixo':
      return .71 * seno + .28 * Math.sin(p * 2) + .17 * Math.sin(p * 3) * Math.exp(-2.2 * t)
        + .14 * Math.sin(p * 4) * Math.exp(-8 * t);
    case 'baixo_curto':
      return .73 * seno + .29 * Math.sin(p * 2) + .23 * Math.sin(p * 3) * Math.exp(-5 * t)
        + .10 * Math.sin(p * 5.01) * Math.exp(-20 * t) + .11 * noise * Math.exp(-60 * t);
    case 'contrabaixo':
      return .77 * seno + .26 * Math.sin(p * 2.003) * Math.exp(-3.7 * t)
        + .18 * Math.sin(p * 4.02) * Math.exp(-18 * t) + .06 * noise * Math.exp(-39 * t);
    case 'cordas':
      return .58 * seno + .24 * Math.sin(p * 2 + .21) + .18 * Math.sin(p * 3 - .3)
        + .11 * Math.sin(p * 4.001 + .18) + .07 * Math.sin(p * 5.997)
        + .19 * Math.sin(p + tau * t * f * .0024);
    case 'pad':
      return .53 * seno + .37 * Math.sin(p * .995 + .5) + .29 * Math.sin(p * 1.005 - .48)
        + .12 * Math.sin(p * 2.001 + .6) + .09 * Math.sin(p * 3.01);
    case 'palheta':
      return .71 * seno + .26 * Math.sin(p * 3) + .12 * Math.sin(p * 5) * Math.exp(-2.7 * t)
        + .07 * Math.sin(p * 7) * Math.exp(-7.6 * t) + .07 * noise * Math.exp(-12 * t);
    case 'metal':
      return .63 * seno + .32 * Math.sin(p * 2) + .22 * Math.sin(p * 3) * Math.exp(-3.1 * t)
        + .18 * Math.sin(p * 4) * Math.exp(-6.4 * t) + .12 * Math.sin(p * 6) * Math.exp(-9.6 * t);
    case 'pulso':
      return .74 * Math.sin(p + .54 * Math.sin(p * 2))
        + .18 * Math.sin(p * 3.001 - .2) + .11 * Math.sin(p * 5) * Math.exp(-5.6 * t);
    case 'harpa':
      return .73 * seno + .23 * Math.sin(p * 2) * Math.exp(-6.5 * t)
        + .23 * Math.sin(p * 3.03) * Math.exp(-11 * t) + .08 * Math.sin(p * 6.13) * Math.exp(-22 * t);
    case 'coro':
      return .64 * seno + .22 * Math.sin(p * 2 + .13) + .14 * Math.sin(p * 4) + .075 * Math.sin(p * 5)
        + .20 * Math.sin(p + tau * t * f * .0031);
  }
  throw new Error('Instrumento desconhecido: ' + v);
}

const timbres = new Map();
function instrumento(voz, altura, duracao) {
  const dur = Math.max(.035, Math.round(duracao * 100) / 100);
  const id = [voz, altura, dur].join('/');
  if (timbres.has(id)) return timbres.get(id);
  const [ataque, fim, corpo, decaimento] = VOZES[voz];
  const dado = new Float32Array(quadros(dur + fim));
  const ruido = gerador(id);
  const f = hz(altura);
  const expressivo = ['cordas', 'palheta', 'metal', 'pulso', 'coro'].includes(voz);
  let fase = 0;
  for (let i = 0; i < dado.length; i++) {
    const t = i / taxa;
    const vibrato = expressivo ? .0038 * rampa(t * 6) * Math.sin(tau * t * 5.1) : 0;
    fase += tau * f * (1 + vibrato) / taxa;
    const env = rampa(t / ataque) * (corpo + (1 - corpo) * Math.exp(-t / decaimento))
      * rampa((dur + fim - t) / fim);
    dado[i] = parcial(fase, f, t, voz, ruido()) * env;
  }
  timbres.set(id, dado);
  return dado;
}

const DURACOES = { bumbo: .25, caixa: .23, palma: .215, aro: .13, chimbal: .073,
  aberto: .29, shaker: .14, tom: .36, prato: .80 };
const bateria = new Map();
function percussao(nome, variacao) {
  const chave = nome + '/' + variacao;
  if (bateria.has(chave)) return bateria.get(chave);
  const dado = new Float32Array(quadros(DURACOES[nome]));
  const sorteio = gerador(chave);
  let meia = 0;
  let baixa = 0;
  let fase = 0;
  let fase2 = 0;
  for (let i = 0; i < dado.length; i++) {
    const t = i / taxa;
    const noise = sorteio();
    baixa += .12 * (noise - baixa);
    meia += .47 * (noise - meia);
    const raspa = (meia - baixa) + .36 * (noise - meia);
    const corpo = meia - .72 * baixa;
    let som = 0;
    const ajuste = 1 + .045 * (variacao - 1);
    if (nome === 'bumbo' || nome === 'tom') {
      const grave = nome === 'bumbo' ? 45 : 102;
      fase += tau * (grave * ajuste + 112 * Math.exp(-56 * t)) / taxa;
      fase2 += tau * (grave * 1.59 + 77 * Math.exp(-39 * t)) / taxa;
      som = Math.sin(fase) * Math.exp(-t / .071) + .21 * Math.sin(fase2) * Math.exp(-t / .032)
        + .23 * raspa * Math.exp(-t / .006);
    } else if (nome === 'caixa' || nome === 'palma' || nome === 'aro') {
      fase += tau * (nome === 'aro' ? 522 : 184 + 29 * Math.exp(-58 * t)) * ajuste / taxa;
      const estalos = nome === 'palma'
        ? [0, .010, .021].reduce((s, p) => s + (t >= p ? Math.exp(-(t - p) * 155) : 0), 0)
        : Math.exp(-t * 160);
      som = .42 * raspa * estalos + .78 * corpo * Math.exp(-t / (nome === 'aro' ? .026 : .049))
        + .31 * Math.sin(fase) * Math.exp(-t / .042);
    } else {
      const escala = { chimbal: .018, aberto: .078, shaker: .034, prato: .23 };
      const lata = [2849, 4213, 5717, 7327].reduce((s, f) => s + Math.sin(tau * f * ajuste * t), 0);
      som = (.93 * raspa + .042 * lata) * Math.exp(-t / escala[nome]);
      if (nome === 'shaker') som *= .52 + .48 * Math.sin(t * tau * 49) ** 2;
    }
    dado[i] = som * rampa(t / .0017) * rampa((dado.length - 1 - i) / quadros(.012));
  }
  bateria.set(chave, dado);
  return dado;
}

class Partitura {
  constructor(duracao, loop) {
    this.duracao = duracao;
    this.loop = loop;
    this.n = quadros(duracao);
    this.esq = new Float32Array(this.n);
    this.dir = new Float32Array(this.n);
    this.sala = new Float32Array(this.n);
  }

  som(tempo, dado, nivel, pan, sala) {
    const inicio = quadros(tempo);
    const le = Math.sqrt((1 - pan) / 2) * nivel;
    const ld = Math.sqrt((1 + pan) / 2) * nivel;
    const wet = sala * nivel;
    const limite = this.loop ? dado.length : Math.min(this.n - inicio, dado.length);
    for (let j = 0; j < limite; j++) {
      const i = (inicio + j) % this.n;
      this.esq[i] += le * dado[j];
      this.dir[i] += ld * dado[j];
      this.sala[i] += wet * dado[j];
    }
  }

  nota(voz, tempo, altura, duracao, nivel, pan = 0, sala = .14) {
    this.som(tempo, instrumento(voz, altura, duracao), nivel, pan, sala);
  }

  golpe(nome, tempo, nivel, pan = 0, variante = 1) {
    this.som(tempo, percussao(nome, variante), nivel, pan, nome === 'bumbo' ? 0 : .12);
  }

  render(maximo, estereo = 1) {
    // Reflexões estéreo aplicadas por período nos loops. As caudas cruzam a emenda.
    const reflexos = [[.028, .27, .09], [.043, -.10, .28], [.068, .19, -.10],
      [.098, .09, .17], [.139, -.08, .10], [.181, .08, -.07],
      [.249, .061, .067], [.323, .042, -.040], [.419, .024, .030]];
    for (const [t, e, d] of reflexos) {
      const atraso = quadros(t);
      const alcance = this.loop ? this.n : this.n - atraso;
      for (let i = 0; i < alcance; i++) {
        const to = (i + atraso) % this.n;
        this.esq[to] += this.sala[i] * e;
        this.dir[to] += this.sala[i] * d;
      }
    }
    let pico = 0;
    for (let i = 0; i < this.n; i++) {
      const meio = (this.esq[i] + this.dir[i]) * .5;
      const lado = (this.esq[i] - this.dir[i]) * .5 * estereo;
      const fade = this.loop ? 1 : rampa(i / quadros(.07)) * rampa((this.n - i - 1) / quadros(1.15));
      this.esq[i] = Math.tanh((meio + lado) * 1.09) * fade;
      this.dir[i] = Math.tanh((meio - lado) * 1.09) * fade;
      pico = Math.max(pico, Math.abs(this.esq[i]), Math.abs(this.dir[i]));
    }
    const nivel = linear(maximo) * 32767 / pico;
    const buf = Buffer.alloc(44 + this.n * 4);
    buf.write('RIFF', 0);
    buf.writeUInt32LE(buf.length - 8, 4);
    buf.write('WAVEfmt ', 8);
    buf.writeUInt32LE(16, 16);
    buf.writeUInt16LE(1, 20);
    buf.writeUInt16LE(2, 22);
    buf.writeUInt32LE(taxa, 24);
    buf.writeUInt32LE(taxa * 4, 28);
    buf.writeUInt16LE(4, 32);
    buf.writeUInt16LE(16, 34);
    buf.write('data', 36);
    buf.writeUInt32LE(this.n * 4, 40);
    for (let i = 0; i < this.n; i++) {
      buf.writeInt16LE(Math.round(this.esq[i] * nivel), 44 + i * 4);
      buf.writeInt16LE(Math.round(this.dir[i] * nivel), 46 + i * 4);
    }
    return buf;
  }
}

const ACORDES = {
  m9: [0, 3, 7, 10, 14], M9: [0, 4, 7, 11, 14],
  m11: [0, 3, 7, 10, 17], M7: [0, 4, 7, 11],
  m7: [0, 3, 7, 10], sus: [0, 5, 7, 10, 14],
  '13': [0, 4, 7, 10, 21], '7b9': [0, 4, 7, 10, 13],
  '7#9': [0, 4, 7, 10, 15], dim: [0, 3, 6, 9],
  add9: [0, 4, 7, 14], mAdd: [0, 3, 7, 14], aberto: [0, 7, 14, 19],
};

function notas(acorde, altura = 46) {
  let raiz = acorde[0];
  while (raiz < altura) raiz += 12;
  return ACORDES[acorde[1]].map((intervalo) => raiz + intervalo);
}

function acorde(p, voz, t, base, dur, nivel, altura = 46, atraso = 0.014) {
  const vozes = notas(base, altura);
  for (let i = 0; i < vozes.length; i++) {
    p.nota(voz, t + i * atraso, vozes[i], dur, nivel * (i ? .80 : 1),
      (i / (vozes.length - 1) - .50) * .70, .21);
  }
}

// Cada frase enumera pulsos, graus do acorde e duração em tempos.
const FRASES = {
  menu: [
    [[.48,2,.80],[1.58,4,.33],[2.29,1,.75],[3.48,3,.38]],
    [[.23,4,.46],[1.22,2,.32],[1.79,3,.76],[3.14,1,.55]],
    [[.83,1,1.30],[2.51,2,.40],[3.14,4,.58]],
  ],
  camarim: [
    [[.39,3,.69],[1.44,2,.49],[2.26,1,1.18]],
    [[.21,0,.93],[1.67,2,.34],[2.11,4,.68],[3.17,3,.53]],
    [[.38,2,.73],[1.64,4,1.05],[3.15,1,.44]],
  ],
  billie_jean: [
    [[.51,1,.24],[1.21,4,.48],[2.04,3,.23],[2.51,2,.45],[3.51,0,.29]],
    [[.26,2,.25],[.77,1,.15],[1.49,3,.45],[2.52,4,.37],[3.27,2,.30]],
    [[.75,4,.43],[1.77,1,.31],[2.34,2,.18],[3.10,3,.48]],
  ],
  thriller: [
    [[.24,0,.95],[1.68,1,.48],[2.33,4,.76]],
    [[.54,4,.54],[1.50,2,.51],[2.46,1,1.35]],
    [[.18,3,.47],[1.09,0,.66],[2.29,2,.31],[3.06,4,.55]],
  ],
  smooth_criminal: [
    [[.33,1,.17],[.85,2,.24],[1.42,4,.43],[2.72,3,.16],[3.07,1,.42]],
    [[.17,3,.32],[.83,2,.17],[1.68,1,.21],[2.33,4,.22],[3.35,2,.44]],
    [[.47,2,.21],[1.15,3,.21],[1.67,4,.28],[2.23,0,.36],[3.4,1,.27]],
  ],
  ultimo_eco: [
    [[.12,1,.70],[1.13,2,.54],[2.04,4,.84],[3.13,3,.47]],
    [[.22,0,.46],[.89,1,.38],[1.68,4,.93],[3.0,2,.61]],
    [[.09,2,1.25],[1.81,3,.34],[2.33,4,.47],[3.17,1,.57]],
  ],
};

const FAIXAS = {
  menu: {
    segundos: 90, bpm: 96, pico: -19.9,
    acordes: [[45,'m9'],[41,'M9'],[48,'M7'],[43,'sus'],[38,'m9'],[41,'add9'],[40,'m7'],[40,'7b9']],
    ponte: [[38,'m9'],[46,'M9'],[41,'M7'],[40,'sus']],
    partes: ['pk','pka','pkal','pkabl','pkbl','pkac','pkal','pkabl','pka'],
    fundo: 'pad', teclas: 'feltro', tema: 'vitral', baixo: 'baixo', pulso: 'lento',
  },
  camarim: {
    segundos: 60, bpm: 80, pico: -21.0,
    acordes: [[50,'M9'],[47,'m9'],[43,'M7'],[45,'sus'],[42,'m7'],[47,'m11'],[43,'M9'],[45,'13']],
    ponte: [[40,'m7'],[42,'m7'],[43,'M9'],[45,'sus']],
    partes: ['pkal','pkabl','pkac','pkabl','pkal'],
    fundo: 'cordas', teclas: 'feltro', tema: 'harpa', baixo: 'contrabaixo', pulso: 'lento',
  },
  billie_jean: {
    segundos: 120, bpm: 112, pico: -19.7,
    acordes: [[39,'m9'],[42,'M9'],[46,'m7'],[44,'13'],[47,'M7'],[42,'M9'],[41,'m7'],[46,'7#9']],
    ponte: [[44,'m9'],[47,'M9'],[45,'dim'],[46,'7b9']],
    partes: ['kbd','kbad','kbdl','pkbdl','kbdc','pkbad','pkbdl','kbdl','pka','kbdc','pkbdl','kbdl','pkbad','kbd'],
    fundo: 'pad', teclas: 'rhodes', tema: 'pulso', baixo: 'baixo_curto', pulso: 'funk',
  },
  thriller: {
    segundos: 120, bpm: 96, pico: -19.6,
    acordes: [[42,'mAdd'],[38,'M9'],[47,'m11'],[37,'7b9'],[45,'M7'],[43,'M7'],[40,'dim'],[37,'7b9']],
    ponte: [[35,'m9'],[36,'dim'],[42,'mAdd'],[37,'sus']],
    partes: ['pba','pbad','pbdl','pkbadl','pkbc','pbdal','pka','pkbdc','pkbdl','pkbdl','padl','pbad'],
    fundo: 'pad', teclas: 'vitral', tema: 'pulso', baixo: 'baixo', pulso: 'sombra',
  },
  smooth_criminal: {
    segundos: 120, bpm: 128, pico: -19.5,
    acordes: [[43,'m9'],[48,'13'],[41,'m11'],[46,'13'],[39,'M9'],[45,'dim'],[50,'7b9'],[43,'mAdd']],
    ponte: [[48,'m9'],[41,'13'],[46,'M9'],[50,'7#9']],
    partes: ['kbd','kbcl','pkbdl','kbdl','kbdc','kbdl','pkba','kbdl','pkbdc','kbdl','pka','kbad','pkbdl','kbdc','kbdl','kbd'],
    fundo: 'cordas', teclas: 'rhodes', tema: 'metal', baixo: 'contrabaixo', pulso: 'swing',
  },
  ultimo_eco: {
    segundos: 120, bpm: 144, pico: -19.1,
    acordes: [[40,'m9'],[36,'M9'],[43,'M7'],[38,'sus'],[45,'m9'],[36,'add9'],[42,'dim'],[47,'7b9']],
    ponte: [[45,'mAdd'],[41,'M9'],[40,'m11'],[47,'7b9']],
    partes: ['pab','pkab','pkbdl','pkbdal','pbadl','pkbdc','pkd','pab','pkbdl','pkbadl','kbdc','pkbdl','pka','pbad','pkbdl','pkbdal','pkbdc','pab'],
    fundo: 'cordas', teclas: 'coro', tema: 'metal', baixo: 'baixo', pulso: 'epico',
  },
};

function baixo(p, f, t, q, b, h) {
  let motivos;
  switch (f.pulso) {
    case 'lento': motivos = [[0,0,1.66,.49],[2.04,7,1.02,.34]]; break;
    case 'funk': motivos = b % 2
      ? [[0,0,.68,.66],[1.13,12,.25,.39],[1.73,7,.50,.55],[2.63,0,.28,.58],[3.35,10,.28,.37]]
      : [[0,0,.56,.64],[.83,7,.42,.44],[1.63,0,.66,.54],[2.54,12,.27,.47],[3.14,7,.54,.49]]; break;
    case 'sombra': motivos = [[0,0,.75,.58],[1.03,0,.29,.36],[1.54,12,.34,.40],
      [2.01,0,.68,.55],[3.07,b % 4 === 3 ? 6 : 7,.36,.37],[3.56,0,.27,.30]]; break;
    case 'swing': motivos = [[0,0,.75,.70],[1.03,7,.58,.52],[2.02,12,.68,.60],
      [3.05,b % 4 === 3 ? 6 : 10,.55,.53],[3.69,7,.20,.30]]; break;
    default: motivos = [[0,0,.59,.59],[.75,0,.23,.43],[1.24,7,.46,.50],[2,0,.64,.64],
      [2.82,12,.29,.41],[3.32,7,.34,.52]]; break;
  }
  for (const [tempo, intervalo, dur, vol] of motivos) {
    p.nota(f.baixo, t + tempo * q, h[0] + intervalo, dur * q, vol * .60, 0, .025);
  }
}

function ritmo(p, f, t, q, b, forte) {
  let mapa;
  if (f.pulso === 'funk') mapa = [[0,.68],[.75,.28],[2,.58],[2.75,.36],[3.50,.25]];
  else if (f.pulso === 'swing') mapa = [[0,.64],[1.50,.26],[2,.53],[3.50,.32]];
  else if (f.pulso === 'sombra') mapa = [[0,.68],[1.50,.36],[2,.61],[3.25,.42]];
  else mapa = [[0,.68],[.75,.38],[1.50,.36],[2,.64],[2.75,.41],[3.5,.45]];
  const peso = forte ? 1 : .71;
  for (const [tempo, vol] of mapa) p.golpe('bumbo', t + tempo * q, vol * .67 * peso, 0, b % 3);
  const caixa = f.pulso === 'swing' ? 'aro' : (f.pulso === 'funk' ? 'palma' : 'caixa');
  for (const tempo of [1, 3]) p.golpe(caixa, t + tempo * q, .34 * peso, -.08, b % 3);
  for (let i = 0; i < 8; i++) {
    const par = i % 2 === 0;
    const swing = !par && f.pulso === 'swing' ? .115 : 0;
    const voz = i === 6 && b % 2 === 0 ? 'aberto' : 'chimbal';
    p.golpe(voz, t + (i / 2 + swing) * q, (par ? .18 : .116) * peso, par ? .13 : .36, (i + b) % 3);
  }
  if (b % 4 === 3) {
    p.golpe('tom', t + 3.21 * q, .25, -.34);
    p.golpe('tom', t + 3.66 * q, .25, .22, 2);
  }
  if (b % 8 === 4 && forte) p.golpe('prato', t + .012, .29, .37);
}

function comporLoop(nome, f) {
  const p = new Partitura(f.segundos, true);
  const q = 60 / f.bpm;
  const total = Math.round(p.duracao / (4 * q));
  if (f.partes.length * 4 !== total) throw new Error('Forma inválida em ' + nome);
  for (let b = 0; b < total; b++) {
    const bloco = Math.floor(b / 4);
    const secao = f.partes[bloco];
    const t = b * 4 * q;
    const ponte = bloco % 5 === 2 || (secao.includes('c') && !secao.includes('l'));
    const h = ponte ? f.ponte[b % 4] : f.acordes[b % f.acordes.length];
    if (secao.includes('p')) {
      const amplitude = nome === 'ultimo_eco' ? .15 : .115;
      acorde(p, f.fundo, t, h, 3.69 * q, amplitude, 45, .018);
    }
    if (secao.includes('k')) {
      const suave = f.pulso === 'lento';
      const batidas = suave ? [.04, 2.1] : f.pulso === 'swing' ? [.35,1.65,2.52,3.53] : [.42,1.59,2.76];
      for (const batida of batidas) {
        acorde(p, f.teclas, t + batida * q, h, q * (suave ? 1.54 : .23), suave ? .15 : .107, 49, suave ? .037 : .009);
      }
    }
    if (secao.includes('a')) {
      const vozes = notas(h, 55);
      const onda = [0, 2, 4, 1, 2, 3, 0, 4];
      const passo = f.pulso === 'lento' ? .5 : .25;
      for (let i = 0; i < 4 / passo; i++) {
        const grau = onda[(i + 2 * (b % 3)) % onda.length] % vozes.length;
        const vol = (i % 4 === 0 ? .132 : .085) * (secao.includes('l') ? .76 : 1);
        p.nota(nome === 'camarim' ? 'harpa' : 'vitral', t + (i * passo + .027) * q, vozes[grau], .47 * q,
          vol, (i % 2 ? .26 : -.31), .24);
      }
    }
    if (secao.includes('b')) baixo(p, f, t, q, b, h);
    if (secao.includes('d')) ritmo(p, f, t, q, b, secao.includes('l'));
    if (secao.includes('c')) {
      const vozes = notas(h, 46);
      for (const [pulso, grau, dur] of [[.41,1,.72],[1.70,2,.48],[3.05,0,.57]]) {
        p.nota(nome === 'smooth_criminal' ? 'palheta' : f.fundo, t + pulso * q,
          vozes[grau], dur * q, .19, .30, .22);
      }
    }
    if (secao.includes('l')) {
      const vozes = notas(h, nome === 'ultimo_eco' ? 53 : 55);
      const frases = FRASES[nome];
      const frase = frases[(b % 4 === 3 ? 2 : b % 2) % frases.length];
      for (const [pulso, grau, dur] of frase) {
        const altura = vozes[grau % vozes.length] + (b % 8 === 6 && grau < 2 ? 12 : 0);
        p.nota(f.tema, t + pulso * q, altura, dur * q, f.pulso === 'lento' ? .20 : .25, -.11, .24);
        if (secao.includes('p') && b % 4 === 3 && (nome === 'ultimo_eco' || nome === 'smooth_criminal')) {
          p.nota('palheta', t + (pulso + .07) * q, altura - 12, dur * .85 * q, .13, .28, .20);
        }
      }
    }
  }
  return p.render(f.pico);
}

// Motivo original recorrente das cutscenes. Os pulsos são medidos em segundos.
function lembranca(p, t, voz, centro, escala, amp) {
  const motivo = [[0,0,.48],[.48,5,.40],[.94,2,.59],[1.62,9,1.0]];
  for (const [inicio, nota, duracao] of motivo) {
    p.nota(voz, t + inicio * escala, centro + nota, duracao * escala, amp, -.16, .31);
  }
}

function compassoCinema(p, t, ate, harmonia, fundo, lead, raiz, tipo, nivel = 1) {
  const parte = (ate - t) / harmonia.length;
  for (let i = 0; i < harmonia.length; i++) {
    const h = harmonia[i];
    const inicio = t + i * parte;
    acorde(p, fundo, inicio, h, parte * .78, .135 * nivel, 46, .032);
    if (tipo !== 'silencio') {
      p.nota(tipo === 'clube' ? 'contrabaixo' : 'baixo', inicio + .06, h[0], parte * .55, .24 * nivel, 0, .08);
      const vozes = notas(h, 57);
      for (let a = 0; a < 4; a++) {
        const pulso = tipo === 'clube' ? [.13,.40,.62,.81][a] : [.08,.27,.54,.75][a];
        p.nota(lead, inicio + parte * pulso, vozes[(a * 2 + i) % vozes.length],
          parte * .18, .148 * nivel, (a - 1.5) * .19, .23);
      }
      if (tipo === 'clube' || tipo === 'marcha') {
        p.golpe('bumbo', inicio + .025, .33 * nivel);
        p.golpe(tipo === 'marcha' ? 'tom' : 'aro', inicio + parte * .56, .24 * nivel, .25);
        p.golpe('shaker', inicio + parte * .74, .19 * nivel, -.23);
      }
    }
  }
  if (raiz > 0) lembranca(p, t + .10, lead, raiz, Math.min(1.18, (ate - t) / 3.2), .205 * nivel);
}

function introducao() {
  const p = new Partitura(39.5, false);
  compassoCinema(p, 0, 6.90, [[45,'m9'],[41,'M9'],[40,'sus']], 'cordas', 'feltro', 64, 'suave', .79);
  compassoCinema(p, 6.90, 8.30, [[40,'dim']], 'cordas', 'vitral', 0, 'silencio', .60);
  // A ameaça entra junto ao efeito existente. A percussão retorna nas memórias.
  compassoCinema(p, 8.30, 15.90, [[34,'mAdd'],[35,'dim'],[37,'m11'],[40,'7b9']], 'coro', 'pad', 0, 'silencio', .81);
  p.nota('baixo', 8.32, 31, 2.2, .23, 0, .23);
  p.nota('cordas', 11.8, 51, 2.52, .12, -.24, .28);
  compassoCinema(p, 16.35, 19.55, [[39,'m9'],[42,'M9']], 'rhodes', 'pulso', 58, 'clube', .93);
  compassoCinema(p, 19.97, 23.30, [[42,'mAdd'],[37,'7b9']], 'pad', 'vitral', 61, 'suave', .88);
  compassoCinema(p, 23.72, 27.10, [[43,'m9'],[48,'13']], 'rhodes', 'palheta', 63, 'clube', .91);
  compassoCinema(p, 27.60, 34.40, [[45,'m9'],[41,'M9'],[38,'m9'],[40,'7b9']], 'cordas', 'harpa', 64, 'marcha');
  acorde(p, 'coro', 34.40, [45,'mAdd'], 3.65, .19, 46, .05);
  lembranca(p, 34.62, 'vitral', 69, 1.0, .21);
  p.golpe('tom', 34.43, .37, -.10);
  p.golpe('prato', 35.22, .22, .17);
  return p.render(-18.8);
}

function encerramento() {
  const p = new Partitura(46.0, false);
  compassoCinema(p, 0, 8.00, [[40,'mAdd'],[36,'M9'],[38,'sus'],[43,'M9']], 'cordas', 'feltro', 0, 'silencio', .88);
  lembranca(p, 4.19, 'harpa', 62, 1.09, .20);
  compassoCinema(p, 8.75, 14.10, [[39,'m9'],[42,'M9'],[44,'13']], 'rhodes', 'vitral', 58, 'clube', .89);
  compassoCinema(p, 14.85, 20.20, [[42,'mAdd'],[38,'M9'],[42,'add9']], 'cordas', 'vitral', 61, 'suave', .91);
  compassoCinema(p, 20.95, 27.15, [[43,'m9'],[48,'13'],[46,'M9']], 'rhodes', 'palheta', 63, 'clube', .92);
  compassoCinema(p, 27.90, 35.26, [[50,'M9'],[47,'m9'],[43,'M9'],[45,'sus']], 'feltro', 'harpa', 62, 'suave', .90);
  // A nota do espelho aos 35,70 s fica sozinha acima da sustentação.
  acorde(p, 'cordas', 35.24, [45,'aberto'], 2.42, .080, 43, .052);
  acorde(p, 'coro', 38.25, [50,'M9'], 3.07, .17, 46, .06);
  lembranca(p, 38.47, 'feltro', 62, 1.08, .215);
  acorde(p, 'cordas', 42.0, [43,'M7'], 2.04, .135, 45, .058);
  acorde(p, 'feltro', 44.12, [50,'add9'], 1.68, .17, 48, .04);
  return p.render(-19.1);
}

const programas = Object.entries(FAIXAS).map(([nome, f]) => ['Music', nome, () => comporLoop(nome, f)]);
programas.push(['Cinematics', 'introducao', introducao], ['Cinematics', 'encerramento', encerramento]);
for (const [pasta, nome, produzir] of programas) {
  if (process.argv[3] && process.argv[3] !== nome) continue;
  timbres.clear();
  const destino = join(pastaAudio, pasta, nome + '.ogg');
  const saida = spawnSync(ffmpeg, ['-hide_banner', '-v', 'error', '-y', '-f', 'wav', '-i', 'pipe:0',
    '-map_metadata', '-1', '-c:a', 'libvorbis', '-q:a', '5', destino], { input: produzir(), encoding: 'utf8' });
  if (saida.status !== 0) throw new Error(String(saida.error || saida.stderr));
  console.log(pasta + '/' + nome + '.ogg');
}
