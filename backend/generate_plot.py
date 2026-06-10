import matplotlib.pyplot as plt
import numpy as np

# Data
metrics = ['Accuracy', 'Precision', 'Recall']
existing_model = [78, 75, 80]
proposed_model = [91, 89, 93]

x = np.arange(len(metrics))  # the label locations
width = 0.35  # the width of the bars

# Create the plot
fig, ax = plt.subplots(figsize=(8, 6))
rects1 = ax.bar(x - width/2, existing_model, width, label='Existing Model (Logistic Regression)', color='gray')
rects2 = ax.bar(x + width/2, proposed_model, width, label='Proposed Model (Random Forest + CNN)', color='royalblue')

# Add some text for labels, title and custom x-axis tick labels, etc.
ax.set_ylabel('Percentage (%)', fontsize=12, fontweight='bold')
ax.set_title('Performance Comparison: Existing Models vs. Proposed Oral Ulcer AI', fontsize=14, fontweight='bold', pad=20)
ax.set_xticks(x)
ax.set_xticklabels(metrics, fontsize=11, fontweight='bold')
ax.set_ylim(0, 100)
ax.legend(fontsize=10)

# Attach a text label above each bar, displaying its height.
def autolabel(rects):
    """Attach a text label above each bar in *rects*, displaying its height."""
    for rect in rects:
        height = rect.get_height()
        ax.annotate(f'{height}%',
                    xy=(rect.get_x() + rect.get_width() / 2, height),
                    xytext=(0, 3),  # 3 points vertical offset
                    textcoords="offset points",
                    ha='center', va='bottom', fontweight='bold')

autolabel(rects1)
autolabel(rects2)

fig.tight_layout()

# Save the plot
plt.savefig('comparison_bar_graph.png', dpi=300, bbox_inches='tight')
print("Graph saved successfully as comparison_bar_graph.png")
