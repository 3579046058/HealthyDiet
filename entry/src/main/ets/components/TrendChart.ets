/**
 * 趋势折线图组件（基于 Canvas）
 */
import { ThemeColors } from '../common/Constants';

@Component
export struct TrendChart {
  @Prop dataPoints: number[] = [];
  @Prop lineColor: string = '#FF6B35';
  @Prop fillColor: string = '#FF6B3522';
  @Prop chartHeight: number = 160;
  @Prop showLabels: boolean = true;
  @Prop labels: string[] = [];
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

  drawChart() {
    const ctx = this.ctx;
    const w = ctx.width;
    const h = ctx.height;
    const points = this.dataPoints;
    if (points.length === 0) return;

    interface Padding {
      left: number;
      right: number;
      top: number;
      bottom: number;
    }

    interface Point {
      x: number;
      y: number;
    }

    const padding: Padding = { left: 10, right: 10, top: 20, bottom: 20 };
    const drawW = w - padding.left - padding.right;
    const drawH = h - padding.top - padding.bottom;
    const maxVal = Math.max(...points, 1);
    const minVal = Math.min(...points);
    const range = maxVal - minVal || 1;

    // 计算每个点的坐标
    const coords: Point[] = points.map((v, i) => {
      const point: Point = {
        x: padding.left + (i / Math.max(points.length - 1, 1)) * drawW,
        y: padding.top + drawH - ((v - minVal) / range) * drawH
      };
      return point;
    });

    // 绘制填充区域（渐变）
    ctx.beginPath();
    ctx.moveTo(coords[0].x, padding.top + drawH);
    for (const p of coords) {
      ctx.lineTo(p.x, p.y);
    }
    ctx.lineTo(coords[coords.length - 1].x, padding.top + drawH);
    ctx.closePath();
    ctx.fillStyle = this.fillColor;
    ctx.fill();

    // 绘制折线
    ctx.beginPath();
    ctx.moveTo(coords[0].x, coords[0].y);
    for (let i = 1; i < coords.length; i++) {
      ctx.lineTo(coords[i].x, coords[i].y);
    }
    ctx.strokeStyle = this.lineColor;
    ctx.lineWidth = 2.5;
    ctx.lineJoin = 'round';
    ctx.stroke();

    // 绘制数据点
    for (const p of coords) {
      ctx.beginPath();
      ctx.arc(p.x, p.y, 3, 0, 2 * Math.PI);
      ctx.fillStyle = this.lineColor;
      ctx.fill();
    }

    // 绘制底部标签
    if (this.showLabels && this.labels.length > 0) {
      ctx.font = '11px sans-serif';
      ctx.fillStyle = ThemeColors.textSecondary(this.theme);
      ctx.textAlign = 'center';
      const step = coords.length > 1 ? Math.max(1, Math.floor(coords.length / 6)) : 1;
      for (let i = 0; i < coords.length; i += step) {
        ctx.fillText(this.labels[i] || '', coords[i].x, h - 4);
      }
    }
  }
}
