# Authoritative tag / entity / intent mappings

Source: DataOps Insights Project mapping tables (provided by the business).
This is the ground truth the pipeline encodes.

## `LOG` token IDs
`S_`=Start (carries `I<intent>` and `E<entity>` ids), `E_`=End, `M_`=Message,
`R_`=Root, `T_`=Tag (categorisation/tracking — present on most sessions).

## `T_` tag grammar
`T_<Outcome><Letter><Roman>_<ClientType>`  e.g. `T_1AII_CPOS`, `T_2BII_CFIXO`

**Outcome digit:** `1` = Contained, `2` = Transferred.

### Contained (1)
| Letter | Meaning | Roman sub-levels |
|---|---|---|
| A | Self-service BOT | I=Solved w/TXT, II=Solved w/integration, III=Solved OS, IV=Auth failed, V=Vending/Upgrade |
| B | Deflection to digital | I=MV App, II=MV Desktop, III=Website Form, IV=Website, V=App+Website, VI=TOBi Web, VII=IVR |
| C | Deflection to assisted | I=Call Center Non-Technical, **II=Call Center Technical**, III=Call Center Commercial, IV=Customer denies, V=Vodafone Store |
| D | Abandoned | |
| E | Error | I=Service Errors |
| F | Service Change Requested | I=Prepaid, II=Postpaid, III=Fixed, IV=Vodafone Service, V=Billing Contact |

### Transferred (2)
| Letter | Meaning | Roman sub-levels |
|---|---|---|
| A | Transferred to Livechat | I=Non-Technical, **II=Technical**, III=Commercial |
| B | Transferred to Call/ACD | I=Non-Technical, **II=Technical**, III=Commercial |

**Support type = TECHNICAL** only for: `1C-II`, `2A-II`, `2B-II`.
Commercial: `1C-III`, `2A-III`, `2B-III`. Non-technical: `1C-I`, `2A-I`, `2B-I`.

### Client type suffix (not a queue)
CPOS=Postpaid, CPRE=Prepaid, CFIXO=Fixed, CCOL=Collaborator, B=Business,
C=Client, N=Non-client, `0`/`#!ETClient!#` placeholders.

## Technical entities (`E#`) used for topic detection
| Group | Entity ids |
|---|---|
| TV | 35 (TV+Box), 36 (OTT), 37 (CATV) |
| Connection/network/voice | 38 (Wifi), 39 (SAT), 40 (Internet cabo), 41 (Voz), 43 (Fixo Generico), 45 (Voz POTS), 46 (Movel Voz), 50 (Internet) |
| Device/equipment | 7 (Equip. & Acessorios), 28 (Furto e Perda), 55 (Equip. Fixo) |
| General fault | 32 (Avaria Comum) |
| Intent signal | I8 = Dificuldades |

> A session's topic is **technical** if any `S_` token carries one of these `E#`
> ids (or intent `I8`). This is more precise than text-keyword matching.

## Corrected outcome / misrouting definitions
- **Bot-contained (FCR)**: outcome `1A` with Roman I/II/III (solved by bot).
- **Human-routed**: transferred (`2A`/`2B`) or assisted-deflection (`1C`).
- **Routed technical**: support type technical (`1C-II`/`2A-II`/`2B-II`).
- **Hard misroute**: technical topic that is human-routed to a **non-technical or
  commercial** skill (`*-I` / `*-III`).
- **Soft misroute**: technical topic deflected to digital (`1B`) / abandoned (`1D`)
  / error (`1E`) and the customer re-contacts within 24h.
- **Correct technical handling**: technical topic that is bot-contained OR routed
  to a technical skill.
