import pandas as pd
import numpy as np
import matplotlib.pyplot as plt

# Read the data from the CSV
df = pd.read_csv('comparison_data.csv')

# Set font style to resemble SPSS output fonts
plt.rcParams['font.sans-serif'] = 'Arial'
plt.rcParams['font.family'] = 'sans-serif'

# Define all metrics to generate plots for
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
    },
    'DataConsumption': {
        'title': 'Simple Bar Mean of dataconsumption by Platform',
        'ylabel': 'Mean dataconsumption',
        'filename': 'spss_dataconsumption_bar.png',
        'labels': ['"Android"', '"Web"']
    }
}

for col, info in metrics.items():
    # Calculate Mean, Standard Deviation, and Count
    stats = df.groupby('Platform')[col].agg(['mean', 'std', 'count'])
    
    # Calculate Standard Error (SE) and 95% Confidence Interval (CI)
    stats['se'] = stats['std'] / np.sqrt(stats['count'])
    stats['ci95'] = 1.96 * stats['se']
    
    # Ensure correct order: Android, then Web
    stats = stats.reindex(['Android', 'Web'])
    
    # Create the figure
    fig, ax = plt.subplots(figsize=(8, 4.5), facecolor='white')
    
    # Draw bars with standard SPSS blue color (#1f77b4 / #008fd5)
    spss_blue = '#1f77b4'
    
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
    
    # Title matching SPSS formatting
    ax.set_title(info['title'], fontsize=12, pad=15)
    
    # Y-axis label matching SPSS formatting
    ax.set_ylabel(info['ylabel'], fontsize=11, labelpad=8)
    
    # X-axis label matching SPSS formatting - changed from algorithm to Platform
    ax.set_xlabel('Platform', fontsize=11, labelpad=12)
    
    # Set y-axis limits dynamically with headroom
    max_value = (stats['mean'] + stats['ci95']).max()
    ax.set_ylim(0, max_value * 1.2)
    
    # Draw light horizontal gridlines
    ax.yaxis.grid(True, linestyle='-', which='major', color='#e0e0e0', zorder=0)
    ax.set_axisbelow(True)
    
    # Style the spines (borders) - left and bottom are visible, top and right are hidden
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    ax.spines['left'].set_color('#7f7f7f')
    ax.spines['bottom'].set_color('#7f7f7f')
    
    # Ticks formatting
    ax.tick_params(colors='#333333', labelsize=10)
    
    # Add the standard SPSS error bar footnote text at the bottom
    fig.text(0.5, 0.05, 'Error Bars: 95% CI', ha='center', fontsize=9, color='#333333')
    fig.text(0.5, 0.01, 'Error Bars: +/- 2 SE', ha='center', fontsize=9, color='#333333')
    
    # Save the output image with high quality
    plt.tight_layout(rect=[0, 0.08, 1, 1])
    plt.savefig(info['filename'], dpi=300, bbox_inches='tight')
    plt.close()
    print(f"Generated SPSS bar graph for {col} -> {info['filename']}")
