"""Monta poses novas em 40 × 40 a partir da arte dos figurinos do projeto.

Rode com Python e Pillow. As coordenadas são inteiras e o pé de apoio fica
na linha 34, logo acima do colisor quando exibido a 2×.
"""
from pathlib import Path
from PIL import Image, ImageDraw
import re

PASTA = Path(__file__).resolve().parent
ANIMACOES = PASTA.parent
FIGURINOS = {
    "billie": ANIMACOES / "BillieJean/michael_terno_escuro_com_chapeu.tres",
    "billie_sem_chapeu": ANIMACOES / "BillieJean/michael_terno_escuro_sem_chapeu.tres",
    "thriller": ANIMACOES / "Thriller/thriller.tres",
    "smooth": ANIMACOES / "SmoothCriminal/michael_terno_claro_com_chapeu.tres",
    "smooth_sem_chapeu": ANIMACOES / "SmoothCriminal/michael_terno_claro_sem_chapeu.tres",
    "camarim": ANIMACOES.parent / "Variantes/michael_terno_claro_sem_chapeu_spriteframes.tres",
}
RAIZ = ANIMACOES.parents[2]
DIRECOES = ["Baixo", "Cima", "Direita", "Esquerda"]
PALETAS = {
    "billie": ("#211c25", "#504052", "#f1dbe4", "#373147", "#eee7df"),
    "thriller": ("#9b1b27", "#ec4355", "#eb5460", "#6a1527", "#302332"),
    "smooth": ("#c6c9d4", "#fbf1dc", "#405a73", "#7e8196", "#29242c"),
    "camarim": ("#545271", "#9091ac", "#accedf", "#312b45", "#2c2532"),
}
CONTORNO = "#161321"
PELE = "#bd7957"
LUVA = "#f1e6d7"

# Poses de perfil. Cada linha define a inclinação, altura dos quadris,
# joelhos/pés e cotovelos/mãos. Os pontos são relativos à linha dos pés.
PERFIL = {
    # x/y do tronco, perna traseira, perna dianteira, braço traseiro, braço dianteiro
    "guarda": (0, 0, (-2,-4,-2,0), (2,-4,3,0), (-4,-9,-4,-5), (3,-8,4,-6)),
    "recuo": (-2,1, (-4,-3,-5,0), (2,-4,4,0), (-6,-8,-6,-6), (-4,-10,-1,-9)),
    "arma": (-1,1, (-4,-4,-5,0), (3,-4,4,0), (-5,-9,-3,-12), (-4,-11,2,-12)),
    "soco": (2,0, (-2,-4,-4,0), (4,-4,6,0), (-2,-10,-5,-8), (8,-10,12,-11)),
    "recolhe": (1,1, (-2,-4,-4,0), (3,-4,5,0), (-3,-9,-5,-6), (6,-9,7,-7)),
    "joelho": (-1,0, (-2,-4,-4,0), (5,-9,5,-5), (-4,-10,-6,-8), (4,-11,2,-14)),
    "chute": (-2,-1, (-3,-4,-4,0), (5,-7,12,-8), (-4,-10,-8,-11), (3,-12,6,-14)),
    "pivo": (-2,1, (-1,-4,0,0), (4,-5,3,0), (-4,-8,-8,-9), (-2,-12,-5,-14)),
    "giro": (1,-1, (-2,-4,-3,0), (7,-5,13,-5), (-5,-11,-8,-13), (4,-10,9,-13)),
    "cruza": (1,0, (-1,-4,3,0), (1,-4,0,-1), (-3,-8,-2,-6), (4,-9,3,-6)),
    "passo_a": (0,0, (-3,-4,-5,0), (3,-5,5,-1), (2,-9,4,-7), (-3,-9,-4,-6)),
    "passo_b": (1,-1, (0,-4,-2,0), (4,-4,5,0), (1,-9,2,-6), (-2,-9,-3,-7)),
    "passo_c": (0,0, (1,-5,5,-1), (-3,-4,-5,0), (-2,-9,-4,-7), (3,-9,5,-6)),
    "passo_d": (1,-1, (2,-4,4,0), (-1,-4,-4,0), (-3,-9,-3,-6), (2,-9,3,-7)),
    "arranque": (2,2, (0,-3,-4,0), (5,-3,6,0), (-1,-8,-5,-8), (3,-7,6,-7)),
    "corrida": (4,0, (-1,-4,-6,-1), (7,-6,9,-4), (0,-9,-5,-8), (8,-9,10,-11)),
    "freio": (2,1, (-4,-4,-7,0), (5,-4,9,0), (-2,-9,-6,-9), (5,-8,7,-6)),
    "deslize_a": (-1,0, (-4,-4,-7,0), (1,-4,4,-1), (-4,-10,-6,-7), (3,-11,1,-14)),
    "deslize_b": (0,1, (1,-3,4,0), (-4,-5,-6,-2), (-4,-9,-6,-6), (4,-10,6,-8)),
    "toque": (0,0, (-1,-4,-3,0), (1,-4,4,0), (-4,-8,-5,-6), (3,-15,2,-19)),
    "lanca": (2,-1, (-2,-4,-4,0), (4,-4,6,0), (-4,-10,-6,-9), (7,-14,11,-15)),
    "segue": (1,0, (-2,-4,-4,0), (3,-4,5,0), (-4,-10,-5,-7), (6,-9,9,-10)),
    "aparar": (-1,1, (-4,-4,-5,0), (4,-5,4,-2), (-5,-11,-6,-13), (2,-12,5,-15)),
    "impacto": (-3,-1, (-5,-4,-6,-1), (1,-4,4,0), (-6,-12,-8,-14), (3,-9,5,-12)),
    "queda": (-4,5, (-6,-3,-7,0), (0,-4,4,0), (-6,-8,-9,-6), (2,-6,6,-3)),
    "ajoelha": (-5,8, (-7,-3,-9,0), (0,-3,3,0), (-7,-5,-11,-2), (2,-4,5,-1)),
}
SEQUENCIAS = {
    "Andar": (10, ["guarda", "passo_a", "passo_b", "guarda", "passo_c", "passo_d"], [1]*6),
    "Parado": (5, ["guarda"], [1]),
    "Soco": (18, ["guarda", "arma", "soco", "recolhe", "guarda"], [1,1,1.7,1,1]),
    "Chute": (17, ["guarda", "joelho", "chute", "recolhe", "guarda"], [1,1.15,1.5,1,1]),
    "Giro": (16, ["pivo", "cruza", "giro", "chute", "freio", "guarda"], [1,1.2,1.3,1,.8,1]),
    "Dash": (19, ["arranque", "corrida", "passo_a", "freio", "guarda"], [1,1,1,1,1]),
    "Moonwalk": (16, ["toque", "deslize_a", "cruza", "deslize_b", "deslize_a", "guarda"], [1]*6),
    "Esquiva": (16, ["aparar", "recuo", "deslize_a", "guarda"], [1,1.2,1,1]),
    "Dano": (14, ["impacto", "queda", "aparar", "guarda"], [1.4,1.3,1,1]),
    "Arremesso": (17, ["toque", "arma", "lanca", "segue", "guarda"], [1,1.35,1.2,1,1]),
    "EmVoo": (5, ["guarda"], [1]),
    "Recuperar": (17, ["aparar", "segue", "toque", "guarda"], [1,1,1.2,1]),
    "Morte": (9, ["impacto", "queda", "ajoelha", "chao", "chao"], [1,1,1.2,1,2]),
}


def ler_cabecas(arquivo):
    txt = arquivo.read_text(encoding="utf-8-sig")
    origem = re.search(r'path="res://([^"]+\.png)"', txt)[1]
    arte = Image.open(RAIZ / origem).convert("RGBA")
    regioes = {nome: tuple(map(int, ret.split(", "))) for nome, ret in re.findall(
        r'\[sub_resource type="AtlasTexture" id="([^"]+)"\].*?region = Rect2\(([\d, ]+)\)', txt, re.S)}
    quadros = {nome: re.findall(r'SubResource\("([^"]+)', bloco)[0] for bloco, nome in re.findall(
        r'\{\s*"frames":\s*\[(.*?)\]\s*,\s*"loop": .*?\s*,\s*"name":\s*&"([^"]+)"', txt, re.S)}
    rostos = {}
    for direcao in DIRECOES:
        x, y, w, h = regioes[quadros[direcao]]
        img = arte.crop((x, y, x+w, y+h))
        left, top, right, bottom = img.getbbox()
        rostos[direcao] = img.crop((left, top, right, bottom - 10))
    return rostos


def desenhar(rosto, direcao, pose, paleta):
    img = Image.new("RGBA", (40, 40))
    d = ImageDraw.Draw(img)
    casaco, brilho, camisa, calca, sapato = paleta
    perfil = direcao in ("Direita", "Esquerda")
    costas = direcao == "Cima"
    lado = -1 if direcao == "Esquerda" else 1
    centro, solo = 20, 34
    if pose == "chao":
        d.polygon([(10,32),(13,26),(19,27),(24,28),(34,30),(34,34),(10,34)], fill=CONTORNO)
        d.polygon([(13,31),(15,28),(22,29),(25,31),(30,31),(30,33),(12,33)], fill=casaco)
        d.line([(18,31), (22,31), (26,33)], fill=brilho, width=2)
        d.rectangle((29,31,34,33), fill=sapato, outline=CONTORNO)
        img.alpha_composite(rosto, (1, 34-rosto.height))
        return img
    x, baixo, perna_a, perna_b, braco_a, braco_b = PERFIL[pose]
    if not perfil:
        x = 0 if pose not in ("giro", "cruza", "impacto", "deslize_a", "deslize_b") else x
        if pose in ("soco", "segue", "lanca", "chute", "joelho"):
            forca = -1 if costas else 1
            ex, ey, maox, maoy = braco_b
            dedos = -17 if costas else -5
            braco_b = (3, -11, 5 + (1 if pose == "lanca" else 0), dedos + (forca if pose == "segue" else 0))
            if pose in ("chute", "joelho"):
                perna_b = (4, -6, 5, -12 if costas else 1)
    # Corpos são desenhados por trás e à frente em camadas conforme a direção.
    t = lambda px, py: (centro + px * lado, min(35, solo + py))
    quadril = -7 + baixo // 2
    ombro = -13 + baixo
    def membro(inicio, fim, cor, ponta, largura):
        joelho_x, joelho_y, ponta_x, ponta_y = fim
        linha = [t(*inicio), t(joelho_x, joelho_y), t(ponta_x, ponta_y)]
        d.line(linha, fill=CONTORNO, width=largura, joint="curve")
        d.line(linha, fill=cor, width=largura-2, joint="curve")
        p, q = linha[-1]
        d.rectangle((p-1,q-1,p+1,q), fill=ponta)
    membro((x-2, quadril), perna_a, calca, sapato, 5)
    membro((x-(2 if perfil else 4), ombro+1), braco_a, casaco, PELE, 5)
    membro((x+2, quadril), perna_b, calca, sapato, 5)
    w = 4 if perfil else 5
    d.polygon([t(x-w,ombro),t(x+w,ombro),t(x+w-1,quadril),t(x-w+1,quadril)], fill=CONTORNO)
    d.polygon([t(x-w+1,ombro+1),t(x+w-1,ombro+1),t(x+w-2,quadril-1),t(x-w+2,quadril-1)], fill=casaco)
    d.line([t(x-w+1,ombro+1), t(x-1,ombro+1),t(x-2,quadril-1)], fill=brilho)
    if not costas:
        d.line([t(x+1,ombro+1),t(x+1,quadril-1)], fill=camisa)
    membro((x+(1 if perfil else 4), ombro+2), braco_b, casaco, LUVA, 5)
    cabeca = centro + lado*x + (1 if perfil and lado > 0 else 0)
    img.alpha_composite(rosto, (cabeca-rosto.width//2, solo + ombro + 2-rosto.height))
    # A mão no chapéu fica na frente da aba, com contorno próprio.
    if pose in ("toque", "lanca", "aparar") and braco_b[3] < ombro:
        xx, yy = t(braco_b[2], braco_b[3])
        d.rectangle((xx-2, yy-1, xx+1, yy+1), fill=CONTORNO)
        d.point((xx,yy), fill=LUVA)
    return img


def gerar(nome, cabecas):
    arte = []
    anims = []
    for direcao in DIRECOES:
        for acao, (fps, poses, tempos) in SEQUENCIAS.items():
            ids = []
            for i, pose in enumerate(poses):
                sem = acao == "EmVoo" or (acao == "Arremesso" and i >= 2) or (acao == "Recuperar" and i < 2)
                outro = nome + "_sem_chapeu"
                rosto = cabecas[outro if sem and outro in cabecas else nome][direcao]
                sprite = desenhar(rosto, direcao, pose, PALETAS[nome.removesuffix("_sem_chapeu")])
                ids.append(len(arte))
                arte.append(sprite)
            tag = direcao if acao == "Andar" else f"{acao}_{direcao}"
            anims.append((tag, ids, tempos, fps, acao == "Andar"))
            if direcao == "Baixo" and acao in ("Parado", "Morte"):
                anims.append((acao, ids, tempos, fps, False))
    largura = 16
    atlas = Image.new("RGBA", (40*largura, 40*((len(arte)+largura-1)//largura)))
    linhas = ["[gd_resource type=\"SpriteFrames\" format=3]", "",
              f'[ext_resource type="Texture2D" path="res://Assets/Michael/Animacoes/Combate/{nome}.png" id="atlas"]', ""]
    for i, frame in enumerate(arte):
        x, y = i % largura * 40, i // largura * 40
        atlas.paste(frame, (x, y))
        linhas += [f'[sub_resource type="AtlasTexture" id="F{i}"]',
                   'atlas = ExtResource("atlas")', f"region = Rect2({x}, {y}, 40, 40)",
                   "filter_clip = true", ""]
    linhas += ["[resource]", "animations = ["]
    for tag, ids, duracoes, fps, loop in anims:
        frames = ", ".join(f'{{"duration": {float(d):.2f}, "texture": SubResource("F{i}")}}'
                           for i, d in zip(ids, duracoes))
        linhas.append(f'{{"frames": [{frames}], "loop": {str(loop).lower()}, "name": &"{tag}", "speed": {fps}.0}},')
    linhas.append("]")
    atlas.save(PASTA / f"{nome}.png", optimize=True)
    (PASTA / f"{nome}.tres").write_text("\n".join(linhas) + "\n", encoding="utf-8")


if __name__ == "__main__":
    cabecas = {nome: ler_cabecas(fonte) for nome, fonte in FIGURINOS.items()}
    for nome in FIGURINOS:
        gerar(nome, cabecas)
