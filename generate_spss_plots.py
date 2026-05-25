import pandas as pd
import numpy as np
import matplotlib.pyplot as plt

# Read the data from the CSV if it exists (for other plots)
try:
    df = pd.read_csv('comparison_data.csv')
    has_csv = True
except Exception:
    has_csv = False

# Set font style to resemble SPSS output fonts
plt.rcParams['font.sans-serif'] = 'Arial'
plt.rcParams['font.family'] = 'sans-serif'

# 1. Generate standard metrics from CSV (if CSV is available)
if has_csv:
    metrics = {
        'Speed_ms': {
            'title': 'Simple Bar Mean of Speed_ms by Platform',
            'ylabel': 'Mean Speed_ms',
            'filename': 'spss_speed_bar.png',
            'labels': ['"Android"', '"Web"']
        },
        'Usability_1to5': {
            'title': 'Simple Bar Mean of Usability_1to5 by Platform',
            'ylabel': 'Mean Usability_1to5',
            'filename': 'spss_usability_bar.png',
            'labels': ['"Android"', '"Web"']
        },
        'ResponseTime_s': {
            'title': 'Simple Bar Mean of ResponseTime_s by Platform',
            'ylabel': 'Mean ResponseTime_s',
            'filename': 'spss_responsetime_bar.png',
            'labels': ['"Android"', '"Web"']
        },
        'Satisfaction_1to5': {
            'title': 'Simple Bar Mean of Satisfaction_1to5 by Platform',
            'ylabel': 'Mean Satisfaction_1to5',
            'filename': 'spss_satisfaction_bar.png',
            'labels': ['"Android"', '"Web"']
        }
    }

    for col, info in metrics.items():
        stats = df.groupby('Platform')[col].agg(['mean', 'std', 'count'])
        stats['se'] = stats['std'] / np.sqrt(stats['count'])
        stats['ci95'] = 1.96 * stats['se']
        stats = stats.reindex(['Android', 'Web'])
        
        fig, ax = plt.subplots(figsize=(8, 4.5), facecolor='white')
        spss_blue = '#008fd5'
        
        bars = ax.bar(
            info['labels'],
            stats['mean'],
            yerr=stats['ci95'],
            capsize=15,
            color=spss_blue,
            edgecolor='#7f7f7f',
            linewidth=0.8,
            width=0.6,
            zorder=3,
            error_kw=dict(ecolor='black', lw=1.2, capthick=1.2)
        )
        
        ax.set_title(info['title'], fontsize=12, pad=15)
        ax.set_ylabel(info['ylabel'], fontsize=11, labelpad=8)
        ax.set_xlabel('Platform', fontsize=11, labelpad=12)
        
        max_value = (stats['mean'] + stats['ci95']).max()
        ax.set_ylim(0, max_value * 1.2)
        
        ax.yaxis.grid(True, linestyle='-', which='major', color='#e0e0e0', zorder=0)
        ax.set_axisbelow(True)
        
        ax.spines['top'].set_visible(False)
        ax.spines['right'].set_visible(False)
        ax.spines['left'].set_color('#7f7f7f')
        ax.spines['bottom'].set_color('#7f7f7f')
        
        ax.tick_params(colors='#333333', labelsize=10)
        
        fig.text(0.5, 0.05, 'Error Bars: 95% CI', ha='center', fontsize=9, color='#333333')
        fig.text(0.5, 0.01, 'Error Bars: +/- 2 SE', ha='center', fontsize=9, color='#333333')
        
        plt.tight_layout(rect=[0, 0.08, 1, 1])
        plt.savefig(info['filename'], dpi=300, bbox_inches='tight')
        plt.close()
        print(f"Generated SPSS bar graph for {col} -> {info['filename']}")

# 2. Generate the specific "dataconsumption" vs "algorithm" bar graph matching the user's reference image
# Mean Data Consumption: Web = 28.00 ms, iOS = 30.15 ms.
fig, ax = plt.subplots(figsize=(8, 4.5), facecolor='white')

platforms = ['"IOS"', '"WEB"']
means = [30.15, 28.00]
# CIs matching the visual error bars in the screenshot (approx. 7.0 for iOS, 6.0 for Web)
errors = [7.0, 6.0]

spss_blue = '#1f77b4' # Sky blue color from the SPSS output screenshot

bars = ax.bar(
    platforms,
    means,
    yerr=errors,
    capsize=15,
    color=spss_blue,
    edgecolor='#7f7f7f',
    linewidth=0.8,
    width=0.6,
    zorder=3,
    error_kw=dict(ecolor='black', lw=1.2, capthick=1.2)
)

# Customizing to match the screenshot title and labels exactly
ax.set_title('Simple Bar Mean of dataconsumption by algorithm', fontsize=12, pad=15)
ax.set_ylabel('Mean dataconsumption', fontsize=11, labelpad=8)
ax.set_xlabel('algorithm', fontsize=11, labelpad=12)

# Y-axis limits matching the screenshot (ticks up to 40, max 45)
ax.set_ylim(0, 45)
ax.set_yticks([0, 10, 20, 30, 40])

# Draw light horizontal gridlines
ax.yaxis.grid(True, linestyle='-', which='major', color='#e0e0e0', zorder=0)
ax.set_axisbelow(True)

# Hide top and right spines
ax.spines['top'].set_visible(False)
ax.spines['right'].set_visible(False)
ax.spines['left'].set_color('#7f7f7f')
ax.spines['bottom'].set_color('#7f7f7f')

ax.tick_params(colors='#333333', labelsize=10)

# Footnotes matching the SPSS output image
fig.text(0.5, 0.05, 'Error Bars: 95% CI', ha='center', fontsize=9, color='#333333')
fig.text(0.5, 0.01, 'Error Bars: +/- 2 SE', ha='center', fontsize=9, color='#333333')

plt.tight_layout(rect=[0, 0.08, 1, 1])
plt.savefig('spss_dataconsumption_bar.png', dpi=300, bbox_inches='tight')
plt.close()
print("Generated SPSS bar graph for dataconsumption -> spss_dataconsumption_bar.png")
