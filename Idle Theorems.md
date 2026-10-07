# Idle-Theorems — Piano Completo v4

> Idle/incremental sulla carriera accademica di un matematico.
> Engine: **Flame** (game loop, simulazione, animazioni) · UI: **Flutter + Riverpod** · Persistenza: **Hive**.
> *v4 = v3 + numeri di bilanciamento (§13) + formato save Hive (§14).*

---

## 1. Visione e tono

Il concetto centrale: si vive la carriera accademica di un matematico — dagli esercizi ai paper, dalle citazioni all'eredità — attraverso una pipeline idle che riflette come funziona davvero la disciplina.

**Tono (punto aperto)**: due poli da calibrare durante il prototipo:

- *Zen lavagna*: calma, meditativa, guidata dall'estetica, fallimenti minimi.
- *Satira mordace*: peer review, scandali e tenure come protagonisti.

Raccomandazione di default: **satira leggera** — umorismo nel copy, attriti nelle meccaniche ma mai punizioni.

---

## 2. Risorse e core loop

### Pipeline C → P → F

1. **Counting** — esercizi pratici. Speso per sbloccare tecniche e strumenti che aumentano la produzione di Proofing.
2. **Proofing** — lavoro teorico/dimostrazioni. Formalizza i paper e genera Fame.
3. **Fame** — paper e citazioni. Spesa negli sblocchi globali e nel prestige.

Ogni stadio alimenta il successivo: il Counting non si spende per sé, è la chiave per sbloccare il Proofing, che sblocca la Fame.

### Potenziamenti incrociati (trade-off)

| Upgrade | Effetto | Costo |
|---|---|---|
| Borsa di studio | +Counting | Proofing |
| Collaboratore | +Proofing | Fame |
| Seminario | +Fame | Counting |

Regola di design: in ogni momento devono esistere **2–3 scelte realmente competitive** (costo opportunità), mai solo "compra tutto".

### Congetture (ciclo di scoperta)

Pilastro centrale oltre la progressione lineare: formulare congetture nei rami completati, dimostrarle nel tempo, fallire e imparare. Dettaglio completo del sistema nel **§4**.

### Stati di fallimento soft

- **Peer review**: esito probabilistico per ogni paper (accettato / revisione richiesta / rifiutato). Il rifiuto ritarda la Fame ma migliora il paper successivo.
- **Retrazioni**: errori scoperti dopo anni costano Fame e reputazione.
- **Burnout**: spingere troppo riduce l'efficienza; il sabbatico la ripristina (spendere Fame per riposare).

Niente game over: solo attriti che creano decisioni strategiche.

---

## 3. Tech tree = matematica reale

Le materie non sono rami indipendenti: hanno **dipendenze reali**. Completare un ramo composto richiede i genitori già completati: il gate è narrativo ("non puoi fare topologia algebrica senza topologia né algebra").

### Mappa delle dipendenze (DAG)

```
LV0  Logica & Insiemi
      │
LV1  ├─ Algebra Discreta ─┬─ Teoria dei Numeri ─┬─ Teoria N. Analitica
      │                    │                     └─ Crittografia
      │                    ├─ Algebra Astratta ─┬─ Analisi Complessa
      │                    │                    ├─ Geometria Algebrica
      │                    │                    ├─ Topologia Algebrica ─ Teoria delle Categorie
      │                    │                    └─ (→ Analisi Funzionale*)
      │                    ├─ Statistica
      │                    └─ Teoria dell'Informazione ─┐
      │                                                 ├─ Complessità Computazionale
      ├─ Analisi ─────────────┬─ Calcolo Multivariabile ┘        │
      │                        ├─ Topologia ────┬────────────────┤
      │                        │                ├─ Analisi Funz.*┴─ EDP
      │                        ├─ Sistemi Dinamici
      │                        ├─ Teoria della Misura
      │                        └─ (→ Analisi Complessa*, TNA*, AFUN*)
      ├─ Geometria ───────────┘ (con Analisi → Calc. Multi, Topologia, Sistemi)
      └─ Probabilità ─┬─ Statistica* / Processi Stocastici
                      └─ Crittografia* / Teoria Informazione*
```

(`*` = il nodo compare sotto più genitori; la tabella qui sotto è la fonte di verità.)

### Tabella master

| Materia | Lv | Pre-requisiti | Effetto in gioco |
|---|---|---|---|
| Logica & Insiemi | 0 | — | +10% Counting da click; prereq di tutto |
| Algebra Discreta | 1 | L&I | +Counting base; sblocca upgrade combinatori nel negozio |
| Analisi | 1 | L&I | +Proofing base (rigore) |
| Geometria | 1 | L&I | −10% costo sessioni di prova (intuizione visiva) |
| Probabilità | 1 | L&I | +10% tasso di accettazione peer review |
| Teoria dei Numeri | 2 | Alg. Discreta | Moltiplicatore Counting che scala coi teoremi totali |
| Algebra Astratta | 2 | Alg. Discreta | +Proofing; cuore dei campi avanzati |
| Calcolo Multivariabile | 2 | Analisi + Geometria | +Fame per paper (risultati applicativi citati prima) |
| Topologia | 2 | Analisi + Geometria | +1 congettura attiva massima |
| Statistica | 2 | Prob. + Alg. Discreta | Rivela il prossimo trend in anticipo |
| Processi Stocastici | 2 | Prob. + Analisi | Aumenta gli eventi intuizione durante le prove |
| Teoria della Misura | 2 | Analisi + L&I | Cap offline progression +100% |
| Teoria dell'Informazione | 2 | Prob. + Alg. Discreta | −10% costi potenziamenti ("compressione") |
| Sistemi Dinamici | 2 | Analisi + Geometria | La produzione cresce in compounding entro sessione |
| Analisi Complessa | 3 | Alg. Astratta + Analisi | Fame ×2 dai paper dei rami analitici |
| Geometria Algebrica | 3 | Alg. Astratta + Topologia | Doppio effetto raro: +Counting e +Proofing insieme |
| Topologia Algebrica | 3 | Topologia + Alg. Astratta | +Eredità guadagnata al prestige |
| Teoria N. Analitica | 3 | Teor. Numeri + Analisi | Burst Fame grandi; accesso agli endgame numerici |
| Crittografia | 3 | Teor. Numeri + Prob. | Sblocca challenge "run cifrata"; +conversione Fame→Eredità |
| Analisi Funzionale | 3 | Analisi + Topologia | Grande moltiplicatore Proofing; prereq EDP |
| Equazioni alle Derivate Parziali | 4 | Calc. Multivariab. + Anal. Funzionale | Motore Fame forte; sbloca Navier-Stokes |
| Complessità Computazionale | 4 | Teor. Informazione + Alg. Discreta | Sblocca P vs NP; +efficienza upgrade incrociati |
| Teoria delle Categorie | 4 | Alg. Astratta + Topol. Algebrica | Corona finale: +5% a tutte le risorse ("grande unificazione") |

23 nodi: buona densità per un idle senza diventare un spreadsheet. Ogni effetto tocca una leva diversa (C, P, F, rischi, costi, offline, prestige), così completare un ramo cambia *come* si gioca, non solo di quanto.

### Trend di ricerca rotanti

Rotazioni periodiche del peso Fame per materia, sempre **causate da eventi narrativi** ("un risultato in teoria dei codici fa esplodere l'interesse per la combinatorica") e **telegrafate con anticipo**, così il giocatore pianifica invece di reagire al rumore. Un ramo in trend dà anche +25% progresso sulle sue congetture (§4).

### Problemi aperti ↔ ramo richiesto

| Problema | Ramo necessario | Tier |
|---|---|---|
| Goldbach | Teoria dei Numeri (+TNA consigliata) | 5 |
| Collatz | Teoria dei Numeri | 4 |
| Ipotesi di Riemann | Teoria N. Analitica | 5 |
| P vs NP | Complessità Computazionale | 5 |
| Navier-Stokes | Equazioni alle Derivate Parziali | 5 |
| Congettura di Hodge | Topol. Algebrica + Geom. Algebrica | 5 |
| Birch–Swinnerton-Dyer | TNA + Geom. Algebrica (curve ellittiche) | 5 |

### Note di bilanciamento

- **Completamento ramo** = masterizzare N teoremi tramite paper accettati nel campo focalizzato (§13.6): 4 (Lv0) → 8 (Lv1) → 12 (Lv2) → 16 (Lv3) → 20 (Lv4).
- **Sinergia > somma**: ogni ramo composto dà un piccolo bonus extra oltre gli effetti dei genitori — è la ricompensa per l'investimento doppio.
- I tier delle congetture agganciano i livelli: tier 1–2 nei rami Lv1–2, tier 3–4 nei composti, tier 5 solo endgame. La difficoltà delle scoperte sale *insieme* alla profondità dell'albero.

---

## 4. Sistema delle congetture — modello dati

### Ciclo di vita

```
available ──(paga formulazione)──▶ active ──(sessioni di lavoro)──▶ [roll]
   ▲                                                        │        │
   └──────────────(cooldown dopo fallimento)◀── refuted ◀──┘        ▼
                                                            proven (fine)
```

Due fasi distinte: **formulare** (costo una tantum, istantaneo) e **dimostrare** (investimento a sessioni nel tempo). È questo che dà ritmo idle al sistema invece di un singolo bottone.

### Modello statico (dati di bilanciamento, caricati da config)

```dart
class ConjectureDef {
  final String id;                  // "goldbach", "lemma_doppio_conteggio"
  final String name;                // Nome lore mostrato al giocatore
  final List<String> subjects;      // rami che devono essere COMPLETATI
  final int tier;                   // 1..5 (difficoltà)
  final ResourceCost formulation;   // costo una tantum per formularla
  final ResourceCost workPerSession;// costo per sessione di lavoro
  final double progressPerWork;     // progresso base per sessione (%)
  final List<Reward> successRewards;// premio al successo
  final int failureMethodXp;        // XP Metodo sul fallimento
  final Duration retryCooldown;
  final bool isEndgame;             // true = problema aperto famoso
}

enum RewardType { productionMultiplier, unlockBranch, fameBurst, legacyBonus }

class Reward {
  final RewardType type;
  final double value;               // es. 0.25 = +25%
  final String? targetBranch;       // se il premio è legato a un ramo
}
```

### Stato dinamico (persistito su Hive)

```dart
enum ConjectureStatus { available, active, proven, refuted }

class ConjectureState {
  final String defId;
  ConjectureStatus status;
  double progress;              // 0..100
  DateTime lastWorkAt;          // per offline progression
  int attempts;                 // tentativi totali (flavor + anti-spam)
  DateTime? resolvedAt;
}
```

`ConjectureDef` vive nella config (YAML), `ConjectureState` nel save: separarli significa ribilanciare senza toccare i salvataggi degli utenti. Lo schema completo del save è nel §14.

### Risoluzione: fallire fa parte del loop

Al raggiungimento del 100% si esegue il roll:

```
P(successo) = clamp( 0.50 + 0.08 · (livelloMetodo − tier) + bonusRamanujan , 0.15 , 0.95 )
```

- **Successo** → premia (`successRewards`), stato `proven`, bonus permanente.
- **Fallimento** → perdi il 50% del progresso accumulato, guadagni `failureMethodXp` (= 10 · tier) nella skill **Metodo**, cooldown e riprovi.

Il punto chiave: il Metodo sale *grazie* ai fallimenti. Il giocatore debole fallisce presto e diventa forte; il RNG non è mai punitivo puro, è una curva di apprendimento. Questo è il motivo per cui il sistema trattiene meglio di un semplice "investisci e aspetta".

### Regole di gioco attorno al modello

| Regola | Effetto di design |
|---|---|
| Max **2 congetture attive** globali | Forza priorizzazione, mai "tutto insieme" |
| Max **1 attiva per ramo** | Evita farming single-branch |
| Ramo in **trend**: +25% progresso sulle sue congetture | Lega il sistema ai trend rotanti |
| **Evento intuizione** (con Ramanujan o Processi Stocastici): X% a sessione | Progresso extra gratuito, momento "aha!" |
| Formulare richiede ramo completato + soglia Proofing scalata col tier | Gate naturale verso l'endgame |

### Esempio di config

```yaml
conjectures:
  - id: lemma_doppio_conteggio
    name: "Lemmi del doppio conteggio"
    tier: 1
    subjects: [algebra_discreta]
    formulation: { proofing: 500 }
    work_per_session: { counting: 200, proofing: 100 }
    progress_per_work: 12.5            # ~8 sessioni
    success_rewards:
      - { type: production_multiplier, value: 0.25, target: counting }
    failure_method_xp: 10
    retry_cooldown_minutes: 30
    is_endgame: false

  - id: goldbach
    name: "Congettura di Goldbach"
    tier: 5
    subjects: [teoria_numeri_analitica]
    formulation: { proofing: 5e6, fame: 1e4 }
    work_per_session: { proofing: 2e5, fame: 500 }
    progress_per_work: 2.0
    success_rewards:
      - { type: legacy_bonus, value: 500 }
      - { type: production_multiplier, value: 0.50, target: all }
    failure_method_xp: 50
    retry_cooldown_minutes: 720
    is_endgame: true
```

I valori per tier sono tabellati in §13.7.

---

## 5. Fasi di carriera

Meta-struttura di progressione:

| Fase | Sblocca |
|---|---|
| Studente | Click base, prime materie |
| PhD | Tesi da difendere prima che i paper dino Fame piena |
| Postdoc | Potenziamenti incrociati, prime congetture |
| Professore | Allievi assunti che producono Counting automaticamente |

L'automazione è **narrata**: stai costruendo un laboratorio di ricerca, non una fabbrica. Stessa funzione tecnica, esperienza molto più tematica. Le soglie numeriche sono in §13.8.

---

## 6. Prestige: Eredità

La Fame convertita al reboot diventa **Eredità**. Si possono contattare matematici storici, ognuno con perk diverso:

- **Gauss** — accelera il Counting
- **Noether** — potenzia le strutture algebriche
- **Ramanujan** — scoperte casuali / amplifica il ciclo delle congetture (§4)
- **Eulero** — aumenta le citazioni

Lo sblocco di ogni matematico innesca un **evento lore** (una corrispondenza epistolare) che lega narrazione e meccanica. Conversione, costi e regole di reset in §13.9.

---

## 7. Endgame: problemi aperti

Dopo il massimo prestigio: i **sette problemi della tabella in §3** diventano obiettivi a lunghissimo termine con ricompense massive. Reusano la stessa `ConjectureDef` con `is_endgame: true`: stesso motore, numeri più grossi, reward unici (titoli cosmetici, moltiplicatori globali, bonus Legacy enormi).

Challenge opzionali: run costruttivista, run senza paper, run cifrata (sbloccata da Crittografia).

---

## 8. Onboarding — "Il primo semestre"

Prime 10 minuti guidate:

click → primo esercizio → prima tecnica → prima dimostrazione → primo paper → prima citazione.

Obiettivo: il giocatore capisce il flusso C→P→F entro 5 minuti, altrimenti i tre contatori sembrano scollegati. Target temporale: primo paper in < 10 minuti (§13.11).

---

## 9. Grafica ed estetica

Stile: **quaderno di matematica / lavagna / biblioteca universitaria**.

- Sfondo carta gialla o lavagna scura
- Inchiostro nero/blu, gesso bianco, accenti oro per la Fame
- Font serif per titoli, monospace per numeri, handwritten per appunti
- Icone SVG con simboli matematici, grafi, formule

Componenti Flame:

- `SpriteComponent` — nodi teorema e icone
- `ParallaxComponent` — sfondo a strati (lavagna, formule, paper)
- `ParticleSystemComponent` — particelle di formule che si scrivono
- `Effect` — animazioni di sblocco e prestige
- `CameraComponent` — timeline del prestige

UI in overlay Flutter: HUD, negozio, pannello materie, albero prestige, pannello congetture. Per UI dentro il canvas, `flame_ui` (`RectButtonComponent`, `ModalComponent`, `ListComponent`, `ScrollableAreaComponent`).

---

## 10. Architettura tecnica (sintesi)

Principio guida: **Flame gestisce game loop e simulazione; Flutter gestisce l'interfaccia**. FlameGame è la radice del component tree e repository centrale dello stato. I componenti non contengono logica comportamentale né rendering diretto: la logica sta in sistemi/servizi separati.

Stato: Riverpod + `flame_riverpod` (`RiverpodAwareGameWidget`, `RiverpodGameMixin`, `RiverpodComponentMixin`).

```
lib/
├── main.dart
├── game/
│   ├── idle_game.dart              # FlameGame principale
│   ├── components/
│   │   ├── theorem_node.dart       # Nodo teorema animato
│   │   ├── formula_particle.dart   # Particelle formule
│   │   └── timeline_component.dart # Timeline prestige
│   └── systems/
│       ├── production_system.dart  # Calcolo produzione C/P/F
│       ├── upgrade_system.dart     # Gestione potenziamenti
│       ├── prestige_system.dart    # Logica reboot
│       ├── conjecture_system.dart  # Formulare/dimostrare congetture
│       └── career_system.dart      # Fasi di carriera e allievi
├── domain/
│   ├── models/
│   │   ├── resources.dart          # Counting, Proofing, Fame
│   │   ├── subject.dart            # Materie con dipendenze reali
│   │   ├── upgrade.dart            # Potenziamenti
│   │   ├── conjecture.dart         # ConjectureDef / ConjectureState
│   │   ├── mathematician.dart      # Matematici del prestige
│   │   └── open_problem.dart       # Problemi aperti (endgame)
│   └── services/
│       ├── save_service.dart       # Hive save/load
│       ├── offline_service.dart    # Guadagni offline
│       ├── balance_service.dart    # Curve di costo
│       ├── review_service.dart     # Peer review/retrazioni/burnout
│       └── config_loader.dart      # Carica subjects/conjectures da YAML
├── ui/
│   ├── overlays/
│   │   ├── main_menu.dart
│   │   ├── hud.dart                # Contatori e risorse
│   │   ├── shop_overlay.dart       # Negozio potenziamenti
│   │   ├── subject_panel.dart      # Selezione materia
│   │   ├── prestige_overlay.dart   # Albero matematici
│   │   └── conjecture_overlay.dart # Pannello congetture
│   └── widgets/
│       ├── resource_counter.dart
│       ├── upgrade_card.dart
│       └── timeline_widget.dart
└── providers/
    ├── game_state_provider.dart
    ├── upgrade_provider.dart
    ├── prestige_provider.dart
    └── conjecture_provider.dart

assets/
└── config/
    ├── subjects.yaml               # Albero dipendenze + effetti rami
    └── conjectures.yaml            # Congetture e problemi aperti
```

### Performance

- Evita allocazioni per frame: riusa Vector2, Paint, oggetti temporanei come membri di classe
- `initialSize` per pre-creare componenti comuni
- Layers e Snapshots per pre-renderizzare elementi statici (sfondi, griglie)
- Idle = CPU-bound sul calcolo della produzione: calcoli nei sistemi, timer invece di controlli per frame

### Dipendenze

```yaml
dependencies:
  flame: ^1.20.0
  flame_riverpod: ^5.0.0
  flame_ui: ^0.2.0
  flutter_riverpod: ^2.5.0
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  katex_flutter: ^2.0.0   # Per formule matematiche
```

---

## 11. Roadmap aggiornata

**Fase 1 — Prototipo**

- FlameGame base con HUD Flutter
- Contatori C/P/F funzionanti con click
- Prima produzione automatica
- Onboarding "primo semestre"

**Fase 2 — Core loop**

- Pipeline C→P→F completa
- Negozio con costi esponenziali e potenziamenti incrociati
- Albero materie con dipendenze reali (config `subjects.yaml`)

**Fase 3 — Profondità**

- Congetture complete (formulare/dimostrare/fallire, skill Metodo)
- Peer review, retrazioni, burnout
- Fasi di carriera
- Trend rotanti motivati dalla narrativa

**Fase 4 — Prestige ed endgame**

- Albero Eredità con 4–5 matematici
- Eventi lore agli sblocchi
- Problemi aperti come obiettivi a lungo termine (`conjectures.yaml`, is_endgame)
- Automazione tematica (allievi/laboratorio)
- Challenge opzionali
- Offline progression

**Fase 5 — Rifinitura**

- Grafica definitiva (sprite, particelle, transizioni)
- Bilanciamento curve di costo e produzione (validazione dei numeri v0 del §13)
- Export/import salvataggi, PWA per web

---

## 12. Punti aperti

- Tono dominante: zen vs satira (calibrare in Fase 1)
- I numeri del §13 sono una bozza v0: da validare con playtest contro i target di ritmo (§13.11)
- Cifratura del box Hive: attivarla o no (trade-off privacy/performance)
- Eventuale sync server per anti-cheat forte (fuori scope attuale)

---

## 13. Numeri di bilanciamento

I numeri sono una bozza **v0**: contano le *proporzioni*, i valori assoluti si validano con playtest in Fase 1.

### 13.1 Formula generale dei costi

```
costo(n) = base × crescita^n        (n = unità già possedute)
```

| Famiglia | Crescita |
|---|---|
| Produttori Counting | 1.15 |
| Produttori Proofing | 1.15 |
| Teoremi dentro un ramo | 1.5 |
| Potenziamenti incrociati | 1.3 – 1.35 |
| Costo paper (n-esimo) | 1.05 |

### 13.2 Produzione Counting

Click base: **1 C/click** (upgrade "strumenti": +100% per livello, costo 100 × 1.6^n).

| Produttore | Costo base (C) | Produzione (C/s) |
|---|---|---|
| Esercizi guidati | 15 | 0.1 |
| Set di problemi | 100 | 1 |
| Problemi avanzati | 1,100 | 8 |
| Problemi di ricerca | 12,000 | 47 |
| Seminario dottorale | 130,000 | 260 |
| Laboratorio | 1,400,000 | 1,400 |

### 13.3 Produzione Proofing

**Tecniche** (una tantum, pagate in Counting — è qui che la pipeline C→P si sente):

| Tecnica | Costo (C) | Effetto |
|---|---|---|
| Formalizzazione elementare | 200 | Sblocca produzione P base (0.5 P/s) |
| Notazione standard | 5,000 | P ×2 |
| Induzione e ricorsione | 50,000 | P ×2 |
| Metodi moderni | 500,000 | P ×3 |
| Teoria applicata alle prove | 5,000,000 | P ×3 |

**Dimostrazioni in corso** (produttori P):

| Dimostrazione | Costo base (P) | Produzione (P/s) |
|---|---|---|
| Lemma semplice | 50 | 0.5 |
| Proposizione | 600 | 3 |
| Teorema minore | 7,000 | 15 |
| Teorema maggiore | 80,000 | 90 |
| Monografia | 900,000 | 500 |
| Opera magnum | 10,000,000 | 3,000 |

La scala P parte ~40× più cara della scala C: il gate C→P resta percepibile senza bloccare.

### 13.4 Fame: paper e citazioni

- **Costo paper**: 100 P base × 1.05^(n−1), tempo di stesura 60 s.
- **Peer review** (a stesura completata):

| Esito | Probabilità base | Conseguenza |
|---|---|---|
| Accettato | 60% | Fame = 25 × moltiplicatori attivi × (1 + 0.1·paper pubblicati) |
| Revisione richiesta | 30% | Riscrivi a metà costo; Fame finale ×1.25 |
| Rifiutato | 10% | Perdi il costo del paper, +2 XP Metodo |

Probabilità base modificata da: Probabilità (+10% accettazione), Eulero (Fame ×2), trend attivo (Fame ×2 sul ramo in trend).

- **Citazioni passive**: 0.01 F/s per ogni paper pubblicato.

### 13.5 Potenziamenti incrociati

| Upgrade | Costo base | Crescita | Effetto per livello |
|---|---|---|---|
| Borsa di studio | 500 P | 1.3 | Counting +50% |
| Collaboratore | 250 F | 1.35 | Proofing +50% |
| Seminario | 2,000 C | 1.3 | Fame +50% |

### 13.6 Materie: mastery tramite paper

Completamento = N teoremi masterizzati nel ramo (§3). Il vecchio bozzetto con prezzo diretto per teorema (costo crescente 1.5×: primo teorema 100/1k/10k/100k P) è stato **superato**: ogni paper accettato vale un teorema masterizzato del campo focalizzato, senza costo aggiuntivo oltre quello del paper stesso.

Loop: focalizza un campo sbloccato e incompleto → scrivi paper (l'n-esimo della run costa 100 × 1.05ⁿ Proofing, §13.4) → peer review (accettazione 60% / revisione 30% al costo dimezzato / rifiuto 10%) → l'accettazione accredita un teorema e paga la Fame (25 × moltiplicatori × (1 + 0.1 · paper pubblicati nella run); x1.25 se il paper ha superato una revisione). I rifiuti non accreditano nulla ma danno XP Metodo.

| Livello | Teoremi richiesti (= paper accettati minimi) |
|---|---|
| Lv0 | 4 |
| Lv1 | 8 |
| Lv2 | 12 |
| Lv3 | 16 |
| Lv4 | 20 |

I rami composti richiedono i genitori già completati (gate narrativo).

Nota: il costo effettivo di un completamento dipende dai roll di revisione (revisioni e rifiuti lo allungano), quindi non esiste più un "totale P" fisso come nel vecchio bozzetto; le ancore di ritmo restano quelle di §13.11.

### 13.7 Congetture: tabella tier completa

| Tier | Formulazione (P) | Sessione (≈) | Progresso/sessione | Sessioni totali | XP Metodo su fallimento | Cooldown | Tipico premio |
|---|---|---|---|---|---|---|---|
| 1 | 500 | 100 P (+200 C) | 12.5% | 8 | 10 | 30 min | +25% produzione ramo |
| 2 | 5,000 | 800 P | 10% | 8 | 20 | 2 h | +50% produzione ramo |
| 3 | 50,000 | 6,000 P (+500 C) | 8.3% | 12 | 30 | 12 h | +100% ramo o sblocco sotto-ramo |
| 4 | 500,000 | 50,000 P (+1,000 F) | 6.25% | 16 | 40 | 48 h | +200% ramo o burst Fame 10k |
| 5 | 5,000,000 | 250,000 P (+500 F) | 2% | 50 | 50 | 72 h | Premio endgame unico |

Formula di risoluzione (invariata dal §4):
`P(successo) = clamp(0.50 + 0.08·(livelloMetodo − tier) + bonusRamanujan, 0.15, 0.95)`

Gli esempi YAML del §4 corrispondono a tier 1 (`lemma_doppio_conteggio`) e tier 5 (`goldbach`).

### 13.8 Carriera: soglie

Soglia = Fame **cumulativa guadagnata** (non quella attuale, non si resetta dentro il ciclo).

| Fase | Fame cumulativa | Requisito extra | Tempo target |
|---|---|---|---|
| Studente | 0 | — | inizio |
| PhD | 1,000 | Difendere tesi: 500 P una tantum | ~1–2 h |
| Postdoc | 25,000 | — | giorno 1–2 |
| Professore | 500,000 | Primo allievo assunibile | settimana 1–2 |

### 13.9 Prestige: conversione e regole di reset

```
Eredità guadagnata = floor( sqrt( Fame_al_prestige / 100 ) )
```

Controlli: Fame 10⁴ → 10 · 10⁶ → 100 · 10⁸ → 1,000. Ogni punto Eredità: **+2% a tutta la produzione**.

Costi di sblocco matematici (in Eredità) e perk:

| Matematico | Costo | Perk |
|---|---|---|
| Gauss | 10 | Counting ×2 |
| Noether | 50 | Proofing ×2 nei rami algebrici |
| Ramanujan | 200 | Evento intuizione 5%/sessione; +10% P(successo) congetture |
| Eulero | 500 | Fame da citazioni ×2 |

**Cosa si resetta al prestige**: saldi C/P/F, produttori, potenziamenti, rami (teoremi), congetture attive/rifiutate, trend, fase di carriera (torni Studente, ma la risalita è veloce grazie ai moltiplicatori Legacy).
**Cosa persiste**: Eredità, matematici, livello Metodo, congetture **proven** (e i loro premi — "la pubblicazione resta"), cosmetici, statistiche.

### 13.10 Offline, trend, burnout

- **Offline**: cap default **4 ore**, efficienza **50%** della velocità online. Teoria della Misura: cap ×2. Upgradeabile fino a **24 h** max.
- **Trend**: rotazione ogni **72 h**; il ramo in trend dà Fame ×2 sui suoi paper; telegrafato **24 h** prima. Statistica: rivela l'intero calendario 72 h in anticipo.
- **Burnout**: se hai ≥5 paper in revisione simultanea, rischio stress; stato bruciato = −50% produzione per 1 h. **Sabbatico**: costa 10% della Fame attuale, rimuove lo stress istantaneamente.

### 13.11 Target di ritmo (ancora di playtest)

| Milestone | Target |
|---|---|
| Primo paper | < 10 minuti |
| PhD (1k Fame cumul.) | 1–2 h |
| Primo prestige (10 Legacy) | 4–8 h totali |
| Professore (5×10⁵ Fame) | settimana 1–2 |
| Primo problema endgame affrontabile | scala mensile |

Se una milestone scivola oltre il doppio del target, si ritocca la curva corrispondente, non i contenuti.

---

## 14. Formato save Hive

### 14.1 Struttura dei box

Un solo box tipizzato, una chiave principale:

```dart
final box = await Hive.openBox<SaveData>('main_save');
box.put('current', save);          // scrittura atomica su chiave singola
```

Adapter `TypeAdapter<SaveData>` (built_value_serializable va bene). Opzionale: cifratura AES del box via `Hive.initEncryptionKey`.

### 14.2 Schema completo

```dart
class SaveData {
  final int version;                        // 3 — bump ad ogni cambio breaking
  final DateTime savedAt;                   // riferimento offline (anti-cheat)
  final DateTime lastLoadedAt;              // rileva rollback dell'orologio
  final Resources resources;                // saldi attuali
  final Map<String, double> lifetime;       // guadagni cumulativi (gate carriera, no-reset)
  final CareerState career;
  final Map<String, BranchProgress> branches;   // key = id ramo ("algebra_discreta")
  final Map<String, int> producerLevels;        // key = id produttore
  final Map<String, int> upgradeLevels;         // key = id potenziamento
  final List<ConjectureState> conjectures;      // §4 del piano
  final PrestigeState prestige;
  final TrendState trend;
  final int metodoLevel;                      // persiste tra i prestiges
  final Settings settings;
  final Stats stats;
}

class Resources {
  double counting;
  double proofing;
  double fame;
}

class CareerState {
  String stage;            // student | phd | postdoc | professor
  bool thesisDefended;
  int apprentices;         // allievi attivi (automazione narrata)
}

class BranchProgress {
  int theoremsMastered;    // 0..N del livello
  bool completed;
}

class ConjectureState {     // identico al modello runtime (§4)
  final String defId;
  ConjectureStatus status;  // available | active | proven | refuted
  double progress;
  DateTime lastWorkAt;
  int attempts;
  DateTime? resolvedAt;
}

class PrestigeState {
  int legacy;
  int prestigesCount;
  List<String> mathematicians;   // ["gauss", "eulero"]
}

class TrendState {
  String activeSubject;
  DateTime endsAt;
  String nextSubject;
  DateTime nextStartsAt;
}

class Settings {
  String theme;             // lavagna | quaderno
  bool sound;
  bool reducedMotion;
}

class Stats {               // mai usato dalla logica, solo flavor/export
  int totalClicks;
  int papersPublished;
  int papersRejected;
  int retractions;
  int conjecturesSolved;
  int playtimeMs;
}
```

Regole:

- Lo stato transiente Flame (particelle, camera, animazioni) **non entra mai nel save**: viene ricostruito da `SaveData` all'avvio.
- Le congetture con `status == proven` vengono filtrate e mantenute attraverso il reset del prestige (regola §13.9).

### 14.3 Anti-cheat offline

```
elapsed = now - savedAt
if (savedAt < lastLoadedAt) elapsed = 0     // orologio manipolato all'indietro
offlineEarnings = production * min(elapsed, cap) * 0.5
```

- `lastLoadedAt` viene sovrascritto a ogni load: un rollback dell'orologio di sistema produce `savedAt < lastLoadedAt` → guadagno zero.
- Opzionale: firma HMAC sulla serializzazione per scoraggiare l'edit esadecimale (limiti noti: chiave lato client estrattibile; la vera garanzia richiede sync server, fuori scope per ora).

### 14.4 Versioning e migrazioni

- `version` bump ad ogni cambio breaking dello schema.
- Funzione `migrate(SaveData)` a catena (`switch(version)`) che porta N→N+1 passo passo; mai saltare versioni.
- I box delle versioni precedenti restano leggibili per almeno un major prima della rimozione.

### 14.5 Momenti di salvataggio

| Evento | Salvataggio |
|---|---|
| Acquisto / upgrade | sì |
| Prestige, risoluzione congettura | sì |
| App in background (lifecycle pause) | sì |
| Autosave in foreground | ogni 60 s |
| Per frame | **mai** |

### 14.6 Export / import

- Serializzazione JSON → base64 per condivisione testuale.
- Campo `checksum` (CRC32) nell'export: validato prima dell'import.
- Import rifiutato se `version > current` (save più nuovo del build) o checksum non valido.
