"""
build_real_dashboard.py
=======================
Executive dashboard built from the VALIDATED results of the corrected pipeline
run (d1-d8). Numbers are the real figures decoded from the BigQuery outputs, so
this one-pager is leadership-ready (no synthetic placeholder).

Re-run after any pipeline change with refreshed numbers below.
Output: reports/figures/00_executive_dashboard_real.png
"""
import os
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch

RED="#E60000"; DARK="#25282A"; GREY="#7E8083"; LGREY="#E9EAEC"
GREEN="#009900"; AMBER="#FBA600"; BLUE="#0077C8"; INK="#4A4D4E"
plt.rcParams.update({
    "figure.facecolor":"white","axes.facecolor":"white","axes.edgecolor":LGREY,
    "axes.grid":True,"grid.color":LGREY,"grid.linewidth":0.9,"axes.axisbelow":True,
    "axes.spines.top":False,"axes.spines.right":False,"axes.titlesize":13,
    "axes.titleweight":"bold","axes.titlecolor":DARK,"font.size":10.5,"figure.dpi":150})

FIG = os.path.join(os.path.dirname(__file__), "figures")
os.makedirs(FIG, exist_ok=True)

# ---- VALIDATED NUMBERS (from corrected d1-d8 run) -------------------------
TECH = 5_246_389
CORRECT = 2_945_887        # bot-contained + technical-skill
CONTAINED = 782_422        # bot-contained (FCR)
HARD = 525_892             # technical -> wrong human skill
SOFT = 650_089             # deflected/abandoned/error -> returns <=24h
EXTRA_HANDOVERS = 539_467  # handovers on misrouted sessions

# D1c: topic -> (sessions, hard_misroutes, pct)
TOPICS = {
    "General fault (Avaria)": (743998, 203724, 27.38),
    "General difficulty":     (1119213, 170354, 15.22),
    "Device / equipment":     (877840, 53444, 6.09),
    "Connection problem":     (1759809, 70095, 3.98),
    "TV features":            (745529, 28275, 3.79),
}
# D3c: channel -> (sessions, pct)  (volume-meaningful)
CHANNELS = {
    "voice": (2559180, 12.26), "app": (740610, 9.86), "web": (1847709, 6.55),
    "Khoros": (65564, 15.46), "amigo_web": (15502, 30.43),
}
# D4a top leaks: (label, misrouted_sessions)
LEAKS = [
    ("general_fault -> ACD Non-Tech (CFIXO)", 111842),
    ("general_fault -> ACD Non-Tech (CFIXO)", 47121),
    ("general_difficulty -> Livechat Non-Tech (CPOS)", 34390),
    ("general_difficulty -> Livechat Non-Tech (CPRE)", 23909),
    ("general_difficulty -> ACD Non-Tech (B)", 22481),
    ("connection -> ACD Non-Tech (B)", 18802),
    ("general_difficulty -> ACD Non-Tech (CPOS)", 15070),
    ("device_equipment -> Livechat Non-Tech (CPOS)", 14493),
]
# handovers per session by cohort (D2a)
HANDOVERS = {"Correctly routed": 0.49, "Misrouted (hard)": 1.02}


def bar_labels(ax, bars, fmt="{:.0f}", pad=3, color=DARK, horiz=False):
    for b in bars:
        if horiz:
            v = b.get_width()
            ax.annotate(fmt.format(v), (v, b.get_y()+b.get_height()/2),
                        xytext=(4,0), textcoords="offset points", va="center",
                        fontweight="bold", fontsize=9, color=color)
        else:
            v = b.get_height()
            ax.annotate(fmt.format(v), (b.get_x()+b.get_width()/2, v),
                        xytext=(0,pad), textcoords="offset points", ha="center",
                        fontweight="bold", fontsize=9, color=color)


def kpi(ax, title, value, sub, color):
    ax.axis("off")
    ax.add_patch(FancyBboxPatch((0.04,0.08),0.92,0.84,
        boxstyle="round,pad=0.02,rounding_size=0.05", lw=0, fc=LGREY, transform=ax.transAxes))
    ax.add_patch(FancyBboxPatch((0.04,0.08),0.03,0.84, boxstyle="square,pad=0",
        lw=0, fc=color, transform=ax.transAxes))
    ax.text(0.13,0.62,value,fontsize=23,fontweight="bold",color=color,transform=ax.transAxes,va="center")
    ax.text(0.13,0.31,title,fontsize=10.5,fontweight="bold",color=DARK,transform=ax.transAxes,va="center")
    ax.text(0.13,0.16,sub,fontsize=8.5,color=GREY,transform=ax.transAxes,va="center")


def main():
    fig = plt.figure(figsize=(16, 9.6))
    gs = fig.add_gridspec(3, 4, height_ratios=[0.85,1.25,1.25],
                          hspace=0.62, wspace=0.34, left=0.055, right=0.975, top=0.88, bottom=0.07)
    fig.text(0.055,0.955,"TOBi Routing & Escalation - Executive Summary",
             fontsize=20, fontweight="bold", color=DARK)
    fig.text(0.055,0.915,"Technical support requests misrouted into non-technical chat queues",
             fontsize=12, color=GREY)

    any_mis = 100*(HARD+SOFT)/TECH
    cards = [
        ("Technical sessions", f"{TECH/1e6:.1f}M", "in analysis window", INK),
        ("Misrouted", f"{any_mis:.0f}%", f"hard {100*HARD/TECH:.0f}% + soft {100*SOFT/TECH:.0f}%", RED),
        ("Bot-contained (FCR)", f"{100*CONTAINED/TECH:.0f}%", "resolved first contact", GREEN),
        ("Extra handovers", f"{EXTRA_HANDOVERS/1e3:.0f}k", "caused by misroutes", BLUE),
    ]
    for i,(t,v,s,c) in enumerate(cards):
        kpi(fig.add_subplot(gs[0,i]), t, v, s, c)

    # Panel 1: misroute % by topic
    ax1 = fig.add_subplot(gs[1,0:2])
    items = sorted(TOPICS.items(), key=lambda kv: kv[1][2])
    labels = [k for k,_ in items]; pct = [v[2] for _,v in items]; vol=[v[1] for _,v in items]
    cols = [RED if p>=15 else (AMBER if p>=8 else BLUE) for p in pct]
    bars = ax1.barh(labels, pct, color=cols)
    for b,n in zip(bars, vol):
        ax1.annotate(f"{b.get_width():.1f}%  ({n:,} mis)", (b.get_width(), b.get_y()+b.get_height()/2),
                     xytext=(4,0), textcoords="offset points", va="center", fontweight="bold", fontsize=9)
    ax1.set_title("Misroute rate by technical topic  (vague intents leak most)")
    ax1.set_xlabel("% of that topic hard-misrouted"); ax1.margins(x=0.22)

    # Panel 2: misroute % by channel
    ax2 = fig.add_subplot(gs[1,2])
    ch = sorted(CHANNELS.items(), key=lambda kv: kv[1][1])
    b2 = ax2.barh([k for k,_ in ch], [v[1] for _,v in ch], color=INK)
    bar_labels(ax2, b2, "{:.1f}%", horiz=True)
    ax2.set_title("Misroute % by channel"); ax2.margins(x=0.28)

    # Panel 3: handovers
    ax3 = fig.add_subplot(gs[1,3])
    b3 = ax3.bar(list(HANDOVERS), list(HANDOVERS.values()), color=[BLUE,RED], width=.6)
    bar_labels(ax3, b3, "{:.2f}")
    ax3.set_title("Avg transfers / session"); ax3.set_ylim(0, 1.25)
    ax3.tick_params(axis="x", labelsize=8.5)

    # Panel 4: funnel
    ax4 = fig.add_subplot(gs[2,0:2])
    stages = [("Technical requests", TECH, INK),
              ("Correctly handled", CORRECT, GREEN),
              ("Bot-contained (FCR)", CONTAINED, BLUE),
              ("Soft misroute", SOFT, AMBER),
              ("Hard misroute", HARD, RED)]
    for i,(lab,val,c) in enumerate(stages):
        ax4.barh(i, val, color=c, height=.62)
        ax4.annotate(f"{val:,} ({100*val/TECH:.0f}%)", (val,i), xytext=(6,0),
                     textcoords="offset points", va="center", fontweight="bold", fontsize=9)
    ax4.set_yticks(range(len(stages))); ax4.set_yticklabels([s[0] for s in stages])
    ax4.invert_yaxis(); ax4.set_title("What happens to technical requests"); ax4.margins(x=0.22)

    # Panel 5: top leaks
    ax5 = fig.add_subplot(gs[2,2:4])
    lk = list(reversed(LEAKS))
    b5 = ax5.barh([l for l,_ in lk], [n for _,n in lk], color=RED)
    bar_labels(ax5, b5, "{:,.0f}", horiz=True)
    ax5.set_title("Top misroute leaks  (technical topic -> NON-technical queue)")
    ax5.set_xlabel("misrouted sessions"); ax5.margins(x=0.22)
    ax5.tick_params(axis="y", labelsize=8)

    fig.text(0.055,0.012,"Source: corrected TOBi pipeline (standalone d1-d8). "
             "Cost driver = extra handovers + repeat contacts, not session length.",
             fontsize=8, color=GREY, style="italic")
    out = os.path.join(FIG, "00_executive_dashboard_real.png")
    fig.savefig(out, bbox_inches="tight", facecolor="white"); plt.close(fig)
    print("wrote", out)


if __name__ == "__main__":
    main()
