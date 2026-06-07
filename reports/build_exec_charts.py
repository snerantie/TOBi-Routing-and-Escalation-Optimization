"""
build_exec_charts.py
=====================
Generates management-ready charts for the TOBi Routing & Escalation analysis.

Data source priority:
  1. Live BigQuery view  vf-pt-copsvertex-live.tobi_routing_analysis.v_session_master
     (used automatically if google-cloud-bigquery is installed AND auth works,
      and the env var TOBI_USE_SYNTHETIC is not set to "1").
  2. Deterministic SYNTHETIC fallback so the deck renders immediately. Charts are
     watermarked "ILLUSTRATIVE DATA" in this mode.

Output: PNGs in reports/figures/.

Regenerate from real data:
    pip install google-cloud-bigquery pandas db-dtypes matplotlib
    gcloud auth application-default login
    python reports/build_exec_charts.py
"""
import os
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib import font_manager  # noqa: F401
from matplotlib.patches import FancyBboxPatch

# ----------------------------------------------------------------------------
# Brand / management theme
# ----------------------------------------------------------------------------
RED      = "#E60000"   # Vodafone red - primary accent / "problem"
DARK     = "#25282A"   # near-black text
GREY     = "#7E8083"   # secondary
LGREY    = "#E9EaEc"   # light fills / gridlines
GREEN    = "#009900"   # "good"
AMBER    = "#FBA600"   # "watch"
BLUE     = "#0077C8"
INK      = "#4A4D4E"

plt.rcParams.update({
    "figure.facecolor":  "white",
    "axes.facecolor":    "white",
    "axes.edgecolor":    LGREY,
    "axes.grid":         True,
    "grid.color":        LGREY,
    "grid.linewidth":    0.9,
    "axes.axisbelow":    True,
    "axes.spines.top":   False,
    "axes.spines.right": False,
    "axes.titlesize":    14,
    "axes.titleweight":  "bold",
    "axes.titlecolor":   DARK,
    "axes.labelcolor":   INK,
    "text.color":        DARK,
    "xtick.color":       INK,
    "ytick.color":       INK,
    "font.size":         11,
    "figure.dpi":        150,
})

FIG_DIR = os.path.join(os.path.dirname(__file__), "figures")
os.makedirs(FIG_DIR, exist_ok=True)

TOPIC_LABEL = {
    "connection_problem":   "Connection problems",
    "device_damage_repair": "Phone damage / repair",
    "feature_question":     "TV / phone features",
}


# ----------------------------------------------------------------------------
# Data loading
# ----------------------------------------------------------------------------
def load_from_bigquery():
    from google.cloud import bigquery
    project = os.environ.get("TOBI_PROJECT", "vf-pt-copsvertex-live")
    ds      = os.environ.get("TOBI_ANALYSIS_DS", "tobi_routing_analysis")
    client = bigquery.Client(project=project)
    sql = f"""
    SELECT START_MOMENT, CHANNEL, CONFIDENCE_LEVEL, technical_topic_type,
           is_technical_topic, routed_queue_category, routed_queue_subtype,
           final_transfer_target, was_transferred, n_transfers, duration_seconds,
           is_hard_misroute, is_soft_misroute, is_correct_technical_route,
           is_fcr, repeat_contact_24h
    FROM `{project}.{ds}.v_session_master`
    """
    return client.query(sql).to_dataframe(), False


def load_synthetic(n=120_000, seed=7):
    """Deterministic, realistic-looking session-level data for layout/demo."""
    rng = np.random.default_rng(seed)
    channels = rng.choice(["App", "Web", "WhatsApp", "IVR"], n, p=[.45, .25, .20, .10])
    is_tech  = rng.random(n) < 0.34
    topic = np.where(
        is_tech,
        rng.choice(["connection_problem", "device_damage_repair", "feature_question"],
                   n, p=[.46, .21, .33]),
        "non_technical_or_unknown")
    conf = rng.choice(["HIGH", "MEDIUM", "LOW"], n, p=[.55, .30, .15])

    # misroute probability rises as confidence falls and varies by channel
    base = np.select([conf == "HIGH", conf == "MEDIUM", conf == "LOW"], [.08, .20, .42])
    ch_adj = np.select([channels == "IVR", channels == "WhatsApp"], [.10, .05], 0.0)
    p_mis = np.clip(base + ch_adj, 0, .9)
    transferred = is_tech & (rng.random(n) < 0.72)
    hard_mis = is_tech & transferred & (rng.random(n) < p_mis)
    correct  = is_tech & transferred & ~hard_mis
    soft_mis = is_tech & ~transferred & (rng.random(n) < 0.18)
    fcr = (~transferred) & (rng.random(n) < np.where(is_tech, 0.33, 0.6))

    dur = np.where(hard_mis, rng.normal(640, 160, n),
          np.where(correct,  rng.normal(395, 120, n),
          np.where(fcr,      rng.normal(150, 60, n),
                              rng.normal(310, 130, n))))
    dur = np.clip(dur, 20, 3000)

    n_tr = np.where(hard_mis, rng.integers(1, 4, n),
           np.where(correct,  rng.integers(1, 2, n), 0))
    repeat = np.where(hard_mis, rng.random(n) < 0.34,
             np.where(correct,  rng.random(n) < 0.12,
                                rng.random(n) < 0.08))

    nt_dest = rng.choice(["T_1All_CPOS", "T_Vendas", "T_Faturacao", "T_Retencao"],
                         n, p=[.45, .25, .18, .12])
    t_dest = rng.choice(["T_Tec_Avarias", "T_Tec_Suporte"], n, p=[.6, .4])
    dest = np.where(hard_mis, nt_dest, np.where(correct, t_dest, None))
    qcat = np.where(hard_mis, "non_technical", np.where(correct, "technical", "unclassified"))
    qsub = np.where(hard_mis,
                    np.select([dest == "T_1All_CPOS", dest == "T_Vendas",
                               dest == "T_Faturacao", dest == "T_Retencao"],
                              ["sales_commercial", "sales_commercial", "billing", "retention"],
                              "other"),
                    np.where(correct, "tech_support", "n/a"))

    days = rng.integers(0, 60, n)
    start = pd.Timestamp("2025-01-01") + pd.to_timedelta(days, unit="D") \
            + pd.to_timedelta(rng.integers(0, 24*3600, n), unit="s")

    df = pd.DataFrame({
        "START_MOMENT": start,
        "CHANNEL": channels,
        "CONFIDENCE_LEVEL": conf,
        "technical_topic_type": topic,
        "is_technical_topic": is_tech,
        "routed_queue_category": qcat,
        "routed_queue_subtype": qsub,
        "final_transfer_target": dest,
        "was_transferred": transferred,
        "n_transfers": n_tr,
        "duration_seconds": dur,
        "is_hard_misroute": hard_mis,
        "is_soft_misroute": soft_mis,
        "is_correct_technical_route": correct,
        "is_fcr": fcr,
        "repeat_contact_24h": repeat,
    })
    return df, True


def load_data():
    if os.environ.get("TOBI_USE_SYNTHETIC") == "1":
        return load_synthetic()
    try:
        return load_from_bigquery()
    except Exception as e:  # noqa: BLE001
        print(f"[info] BigQuery unavailable ({type(e).__name__}); using synthetic data.")
        return load_synthetic()


# ----------------------------------------------------------------------------
# Helpers
# ----------------------------------------------------------------------------
def footnote(fig, synthetic):
    txt = ("ILLUSTRATIVE DATA - layout preview; regenerate with live BigQuery "
           "(reports/build_exec_charts.py)") if synthetic else \
          "Source: vf-pt-copsvertex-live.tobi_routing_analysis.v_session_master"
    fig.text(0.01, 0.01, txt, fontsize=8, color=GREY, ha="left", va="bottom",
             style="italic")


def bar_labels(ax, bars, fmt="{:.0f}", pad=3, color=DARK):
    for b in bars:
        w = b.get_height()
        ax.annotate(fmt.format(w), (b.get_x() + b.get_width()/2, w),
                    ha="center", va="bottom", xytext=(0, pad),
                    textcoords="offset points", fontsize=10, fontweight="bold",
                    color=color)


def save(fig, name):
    path = os.path.join(FIG_DIR, name)
    fig.savefig(path, bbox_inches="tight", facecolor="white")
    plt.close(fig)
    print("wrote", path)


# ----------------------------------------------------------------------------
# Individual charts
# ----------------------------------------------------------------------------
def chart_misroute_by_topic(df, synthetic):
    tech = df[df.is_technical_topic]
    g = (tech.groupby("technical_topic_type")
             .agg(sessions=("is_technical_topic", "size"),
                  misroutes=("is_hard_misroute", "sum")))
    g["pct"] = 100 * g.misroutes / g.sessions
    g = g.sort_values("misroutes", ascending=True)
    labels = [TOPIC_LABEL.get(i, i) for i in g.index]

    fig, ax = plt.subplots(figsize=(9, 4.5))
    bars = ax.barh(labels, g.misroutes, color=RED)
    for b, p in zip(bars, g.pct):
        ax.annotate(f"{int(b.get_width()):,}  ({p:.0f}%)",
                    (b.get_width(), b.get_y() + b.get_height()/2),
                    xytext=(6, 0), textcoords="offset points",
                    va="center", fontweight="bold", color=DARK, fontsize=10)
    ax.set_title("Where technical requests are misrouted")
    ax.set_xlabel("Misrouted sessions  (share of that topic's technical volume)")
    ax.margins(x=0.18)
    fig.suptitle("D1 - Misrouting by technical topic", x=0.012, ha="left",
                 fontsize=10, color=GREY, y=0.99)
    footnote(fig, synthetic)
    save(fig, "01_misroute_by_topic.png")


def chart_impact_time(df, synthetic):
    tech = df[df.is_technical_topic]
    cohorts = {
        "Bot resolved\n(contained)": tech[tech.is_fcr].duration_seconds.mean(),
        "Correctly routed\n(technical)": tech[tech.is_correct_technical_route].duration_seconds.mean(),
        "Misrouted\n(non-technical)": tech[tech.is_hard_misroute].duration_seconds.mean(),
    }
    s = pd.Series(cohorts) / 60.0  # minutes
    colors = [GREEN, BLUE, RED]
    fig, ax = plt.subplots(figsize=(9, 4.8))
    bars = ax.bar(s.index, s.values, color=colors, width=.62)
    bar_labels(ax, bars, fmt="{:.1f} min")
    ax.set_ylabel("Average handling time (minutes)")
    ax.set_title("Misrouting nearly doubles resolution time")
    ax.set_ylim(0, s.max() * 1.25)
    fig.suptitle("D2 - Impact on resolution time", x=0.012, ha="left",
                 fontsize=10, color=GREY, y=0.99)
    footnote(fig, synthetic)
    save(fig, "02_impact_resolution_time.png")


def chart_root_cause_confidence(df, synthetic):
    tech = df[df.is_technical_topic]
    order = ["HIGH", "MEDIUM", "LOW"]
    g = (tech.groupby("CONFIDENCE_LEVEL")
             .agg(sessions=("is_technical_topic", "size"),
                  mis=("is_hard_misroute", "sum")))
    g = g.reindex([o for o in order if o in g.index])
    g["pct"] = 100 * g.mis / g.sessions

    fig, ax = plt.subplots(figsize=(9, 4.8))
    bars = ax.bar(g.index, g.pct, color=[GREEN, AMBER, RED][:len(g)], width=.6)
    bar_labels(ax, bars, fmt="{:.0f}%")
    ax.set_ylabel("Misroute rate (%)")
    ax.set_xlabel("Intent-detection confidence")
    ax.set_title("Low intent-detection confidence drives misrouting")
    ax.set_ylim(0, g.pct.max() * 1.25)
    fig.suptitle("D3 - Root cause: intent detection", x=0.012, ha="left",
                 fontsize=10, color=GREY, y=0.99)
    footnote(fig, synthetic)
    save(fig, "03_root_cause_confidence.png")


def chart_channel_misroute(df, synthetic):
    tech = df[df.is_technical_topic]
    g = (tech.groupby("CHANNEL")
             .agg(sessions=("is_technical_topic", "size"),
                  mis=("is_hard_misroute", "sum")))
    g["pct"] = 100 * g.mis / g.sessions
    g = g.sort_values("pct", ascending=False)
    fig, ax = plt.subplots(figsize=(9, 4.5))
    bars = ax.bar(g.index, g.pct, color=INK, width=.6)
    bar_labels(ax, bars, fmt="{:.0f}%")
    ax.set_ylabel("Misroute rate (%)")
    ax.set_title("Misroute rate by entry channel")
    ax.set_ylim(0, g.pct.max() * 1.25)
    fig.suptitle("D3 - Root cause: entry point", x=0.012, ha="left",
                 fontsize=10, color=GREY, y=0.99)
    footnote(fig, synthetic)
    save(fig, "04_channel_misroute.png")


def chart_where_landed(df, synthetic):
    mis = df[df.is_hard_misroute]
    g = mis.groupby("routed_queue_subtype").size().sort_values(ascending=True)
    g.index = [i.replace("_", " ").title() for i in g.index]
    fig, ax = plt.subplots(figsize=(9, 4.2))
    bars = ax.barh(g.index, g.values, color=RED)
    for b in bars:
        ax.annotate(f"{int(b.get_width()):,}",
                    (b.get_width(), b.get_y()+b.get_height()/2),
                    xytext=(6, 0), textcoords="offset points",
                    va="center", fontweight="bold")
    ax.set_title("Misrouted technical issues land in non-technical queues")
    ax.set_xlabel("Misrouted sessions")
    ax.margins(x=0.16)
    fig.suptitle("D1 - Destination of misroutes", x=0.012, ha="left",
                 fontsize=10, color=GREY, y=0.99)
    footnote(fig, synthetic)
    save(fig, "05_where_landed.png")


def chart_repeat_by_cohort(df, synthetic):
    tech = df[df.is_technical_topic]
    data = {
        "Correctly routed": 100 * tech[tech.is_correct_technical_route].repeat_contact_24h.mean(),
        "Misrouted": 100 * tech[tech.is_hard_misroute].repeat_contact_24h.mean(),
    }
    s = pd.Series(data)
    fig, ax = plt.subplots(figsize=(8, 4.6))
    bars = ax.bar(s.index, s.values, color=[BLUE, RED], width=.55)
    bar_labels(ax, bars, fmt="{:.0f}%")
    ax.set_ylabel("Customers re-contacting within 24h (%)")
    ax.set_title("Misrouting drives repeat contacts")
    ax.set_ylim(0, s.max() * 1.3)
    fig.suptitle("D2 - Channel load: repeat contacts", x=0.012, ha="left",
                 fontsize=10, color=GREY, y=0.99)
    footnote(fig, synthetic)
    save(fig, "06_repeat_by_cohort.png")


def chart_trend(df, synthetic):
    tech = df[df.is_technical_topic].copy()
    tech["day"] = pd.to_datetime(tech.START_MOMENT).dt.date
    daily = tech.groupby("day").agg(t=("is_technical_topic", "size"),
                                    m=("is_hard_misroute", "sum"))
    daily["pct"] = 100 * daily.m / daily.t
    roll = daily.pct.rolling(7, min_periods=1).mean()
    fig, ax = plt.subplots(figsize=(11, 4.2))
    ax.plot(daily.index, daily.pct, color=LGREY, lw=1.2, label="Daily")
    ax.plot(daily.index, roll, color=RED, lw=2.6, label="7-day average")
    ax.set_ylabel("Misroute rate (%)")
    ax.set_title("Technical misroute rate over time")
    ax.legend(frameon=False, loc="upper right")
    fig.autofmt_xdate()
    fig.suptitle("Trend", x=0.012, ha="left", fontsize=10, color=GREY, y=0.99)
    footnote(fig, synthetic)
    save(fig, "07_trend.png")


def chart_funnel(df, synthetic):
    tech = df[df.is_technical_topic]
    total = len(tech)
    stages = [
        ("Technical requests", total, INK),
        ("Bot resolved (FCR)", int(tech.is_fcr.sum()), GREEN),
        ("Correctly routed", int(tech.is_correct_technical_route.sum()), BLUE),
        ("Misrouted", int(tech.is_hard_misroute.sum()), RED),
    ]
    fig, ax = plt.subplots(figsize=(9, 4.8))
    for i, (lab, val, col) in enumerate(stages):
        ax.barh(i, val, color=col, height=.62)
        ax.annotate(f"{val:,}  ({100*val/total:.0f}%)", (val, i),
                    xytext=(8, 0), textcoords="offset points",
                    va="center", fontweight="bold")
    ax.set_yticks(range(len(stages)))
    ax.set_yticklabels([s[0] for s in stages])
    ax.invert_yaxis()
    ax.set_title("What happens to technical requests")
    ax.set_xlabel("Sessions")
    ax.margins(x=0.18)
    fig.suptitle("D5 - Containment & routing funnel", x=0.012, ha="left",
                 fontsize=10, color=GREY, y=0.99)
    footnote(fig, synthetic)
    save(fig, "08_funnel.png")


# ----------------------------------------------------------------------------
# One-page executive dashboard
# ----------------------------------------------------------------------------
def kpi_card(ax, title, value, sub, color):
    ax.axis("off")
    box = FancyBboxPatch((0.03, 0.08), 0.94, 0.84,
                         boxstyle="round,pad=0.02,rounding_size=0.04",
                         linewidth=0, facecolor=LGREY, transform=ax.transAxes)
    ax.add_patch(box)
    ax.add_patch(FancyBboxPatch((0.03, 0.08), 0.025, 0.84,
                 boxstyle="square,pad=0", linewidth=0, facecolor=color,
                 transform=ax.transAxes))
    ax.text(0.12, 0.62, value, fontsize=26, fontweight="bold", color=color,
            transform=ax.transAxes, va="center")
    ax.text(0.12, 0.30, title, fontsize=11, fontweight="bold", color=DARK,
            transform=ax.transAxes, va="center")
    ax.text(0.12, 0.16, sub, fontsize=8.5, color=GREY, transform=ax.transAxes,
            va="center")


def dashboard(df, synthetic):
    tech = df[df.is_technical_topic]
    n_tech = len(tech)
    hard_pct = 100 * tech.is_hard_misroute.mean()
    fcr_pct  = 100 * tech.is_fcr.mean()
    repeat_pct = 100 * tech.is_hard_misroute.mul(tech.repeat_contact_24h).sum() / max(tech.is_hard_misroute.sum(), 1)
    excess_min = (tech[tech.is_hard_misroute].duration_seconds.mean()
                  - tech[tech.is_correct_technical_route].duration_seconds.mean()) / 60
    hours_saved = excess_min * 60 * tech.is_hard_misroute.sum() / 3600

    fig = plt.figure(figsize=(15, 9.2))
    gs = fig.add_gridspec(3, 4, height_ratios=[0.9, 1.25, 1.25],
                          hspace=0.55, wspace=0.32,
                          left=0.05, right=0.97, top=0.88, bottom=0.07)

    fig.text(0.05, 0.955, "TOBi Routing & Escalation - Executive Summary",
             fontsize=20, fontweight="bold", color=DARK, ha="left")
    fig.text(0.05, 0.915,
             "Reducing misrouting of technical requests into non-technical chat queues",
             fontsize=12, color=GREY, ha="left")

    # KPI cards row
    cards = [
        ("Technical sessions", f"{n_tech:,}", "in analysis window", INK),
        ("Misrouted to wrong queue", f"{hard_pct:.0f}%", "of technical requests", RED),
        ("First-contact resolution", f"{fcr_pct:.0f}%", "technical, bot-contained", GREEN),
        ("Est. agent-hours / window", f"{hours_saved:,.0f}", "recoverable if fixed", BLUE),
    ]
    for i, (t, v, s, c) in enumerate(cards):
        kpi_card(fig.add_subplot(gs[0, i]), t, v, s, c)

    # Panel 1: misroute by topic
    ax1 = fig.add_subplot(gs[1, 0:2])
    g = (tech.groupby("technical_topic_type").is_hard_misroute
              .agg(["size", "sum"]))
    g["pct"] = 100 * g["sum"] / g["size"]
    g = g.sort_values("sum")
    bars = ax1.barh([TOPIC_LABEL.get(i, i) for i in g.index], g["sum"], color=RED)
    for b, p in zip(bars, g.pct):
        ax1.annotate(f"{int(b.get_width()):,} ({p:.0f}%)",
                     (b.get_width(), b.get_y()+b.get_height()/2),
                     xytext=(5, 0), textcoords="offset points", va="center",
                     fontweight="bold", fontsize=9)
    ax1.set_title("Misrouting by technical topic")
    ax1.margins(x=0.22)

    # Panel 2: impact time
    ax2 = fig.add_subplot(gs[1, 2])
    s2 = pd.Series({
        "Resolved": tech[tech.is_fcr].duration_seconds.mean(),
        "Correct": tech[tech.is_correct_technical_route].duration_seconds.mean(),
        "Misrouted": tech[tech.is_hard_misroute].duration_seconds.mean(),
    }) / 60
    b2 = ax2.bar(s2.index, s2.values, color=[GREEN, BLUE, RED], width=.7)
    bar_labels(ax2, b2, fmt="{:.0f}m", pad=2)
    ax2.set_title("Avg handling time")
    ax2.set_ylim(0, s2.max()*1.3)
    ax2.tick_params(axis="x", labelsize=9)

    # Panel 3: confidence root cause
    ax3 = fig.add_subplot(gs[1, 3])
    order = [o for o in ["HIGH", "MEDIUM", "LOW"] if o in tech.CONFIDENCE_LEVEL.unique()]
    gc = tech.groupby("CONFIDENCE_LEVEL").is_hard_misroute.mean().reindex(order)*100
    b3 = ax3.bar(gc.index, gc.values, color=[GREEN, AMBER, RED][:len(gc)], width=.7)
    bar_labels(ax3, b3, fmt="{:.0f}%", pad=2)
    ax3.set_title("Misroute % by confidence")
    ax3.set_ylim(0, gc.max()*1.3)
    ax3.tick_params(axis="x", labelsize=9)

    # Panel 4: funnel
    ax4 = fig.add_subplot(gs[2, 0:2])
    total = n_tech
    stages = [("Technical requests", total, INK),
              ("Bot resolved (FCR)", int(tech.is_fcr.sum()), GREEN),
              ("Correctly routed", int(tech.is_correct_technical_route.sum()), BLUE),
              ("Misrouted", int(tech.is_hard_misroute.sum()), RED)]
    for i, (lab, val, col) in enumerate(stages):
        ax4.barh(i, val, color=col, height=.6)
        ax4.annotate(f"{val:,} ({100*val/total:.0f}%)", (val, i),
                     xytext=(6, 0), textcoords="offset points", va="center",
                     fontweight="bold", fontsize=9)
    ax4.set_yticks(range(len(stages)))
    ax4.set_yticklabels([s[0] for s in stages])
    ax4.invert_yaxis()
    ax4.set_title("What happens to technical requests")
    ax4.margins(x=0.2)

    # Panel 5: repeat contacts
    ax5 = fig.add_subplot(gs[2, 2])
    s5 = pd.Series({
        "Correct": 100*tech[tech.is_correct_technical_route].repeat_contact_24h.mean(),
        "Misrouted": 100*tech[tech.is_hard_misroute].repeat_contact_24h.mean(),
    })
    b5 = ax5.bar(s5.index, s5.values, color=[BLUE, RED], width=.6)
    bar_labels(ax5, b5, fmt="{:.0f}%", pad=2)
    ax5.set_title("Repeat contact (24h)")
    ax5.set_ylim(0, s5.max()*1.3)
    ax5.tick_params(axis="x", labelsize=9)

    # Panel 6: channel
    ax6 = fig.add_subplot(gs[2, 3])
    gch = (tech.groupby("CHANNEL").is_hard_misroute.mean()*100).sort_values(ascending=False)
    b6 = ax6.bar(gch.index, gch.values, color=INK, width=.7)
    bar_labels(ax6, b6, fmt="{:.0f}%", pad=2)
    ax6.set_title("Misroute % by channel")
    ax6.set_ylim(0, gch.max()*1.3)
    ax6.tick_params(axis="x", labelsize=8, rotation=20)

    footnote(fig, synthetic)
    save(fig, "00_executive_dashboard.png")


def main():
    df, synthetic = load_data()
    print(f"Loaded {len(df):,} sessions  (synthetic={synthetic})")
    dashboard(df, synthetic)
    chart_misroute_by_topic(df, synthetic)
    chart_impact_time(df, synthetic)
    chart_root_cause_confidence(df, synthetic)
    chart_channel_misroute(df, synthetic)
    chart_where_landed(df, synthetic)
    chart_repeat_by_cohort(df, synthetic)
    chart_trend(df, synthetic)
    chart_funnel(df, synthetic)
    print("Done. Figures in", FIG_DIR)


if __name__ == "__main__":
    main()
