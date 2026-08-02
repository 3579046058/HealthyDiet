import { ThemeColors } from '../common/Constants';

interface Padding {
  left: number;
  right: number;
  top: number;
  bottom: number;
}

@Component
export struct BarChart {
  @Prop dataPoints: number[] = [];
  @Prop barColor: string = '#03A9F4';
  @Prop labels: string[] = [];
  @Prop chartHeight: number = 140;
  @Prop unit: string = '';
  @StorageLink('currentTheme') theme: string = 'dark';

  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  build() {
    Canvas(this.ctx)
      .width('100%')
      .height(this.chartHeight)
      .onReady(() => {
        this.drawChart();
      })
  }

  drawChart(): void {
    const ctx = this.ctx;
    const w = ctx.width;
    const h = ctx.height;
    const points = this.dataPoints;
    if (points.length === 0) return;

    const padding: Padding = { left: 10, right: 10, top: 10, bottom: 20 };
    const drawW = w - padding.left - padding.right;
    const drawH = h - padding.top - padding.bottom;
    const maxVal = Math.max(...points, 1);
    const barWidth = Math.max(4, drawW / points.length * 0.6);
    const gap = drawW / points.length;

    for (let i = 0; i < points.length; i++) {
      const barH = (points[i] / maxVal) * drawH;
      const x = padding.left + i * gap + (gap - barWidth) / 2;
      const y = padding.top + drawH - barH;

      ctx.beginPath();
      ctx.roundRect(x, y, barWidth, barH, 3);
      ctx.fillStyle = this.barColor;
      ctx.globalAlpha = 0.7 + (points[i] / maxVal) * 0.3;
      ctx.fill();
      ctx.globalAlpha = 1.0;

      if (this.labels.length > i) {
        ctx.font = '9px sans-serif';
        ctx.fillStyle = ThemeColors.textSecondary(this.theme);
        ctx.textAlign = 'center';
        ctx.fillText(this.labels[i], padding.left + i * gap + gap / 2, h - 4);
      }
    }
  }
}
