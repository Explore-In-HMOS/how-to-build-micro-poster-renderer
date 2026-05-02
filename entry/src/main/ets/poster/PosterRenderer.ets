/*
 * PosterRenderer.ets — micro-poster rendering pipeline.
 *
 * This module exposes a RenderNode-based renderer that drives drawing.Canvas
 * directly so every ArkGraphics2D module from the codelab brief
 * (deep-research-report (1).md) actually produces visible pixels:
 *
 *   drawing.RoundRect      → canvas.drawRoundRect(roundFrame)
 *   drawing.ShaderEffect   → brush.setShaderEffect(linearGradient)
 *   drawing.ShadowLayer    → brush.setShadowLayer(shadowLayer)
 *   drawing.MaskFilter     → brush.setMaskFilter(blurMask)
 *   drawing.ImageFilter    → brush.setImageFilter(blurImage)
 *   drawing.PathEffect     → pen.setPathEffect(dash ∘ corner)
 *   drawing.Path           → canvas.drawPath(starPath)
 *   drawing.PathIterator   → walks star path to position decorative ticks
 *   drawing.Matrix         → canvas.concatMatrix(rotateAroundHeader)
 *   drawing.RectUtils      → builds / insets / intersects every rect
 *   drawing.Region         → canvas.clipRegion(roundedBodyRegion)
 *   drawing.Lattice        → canvas.drawImageLattice(pix, lattice, dst, NEAREST)
 *
 * The page hosts this via a NodeContainer(controller) (no ArkUI Canvas
 * component is used).
 */

import { common2D, drawing } from '@kit.ArkGraphics2D';
import { image } from '@kit.ImageKit';
import { DrawContext, FrameNode, NodeController, RenderNode, UIContext } from '@kit.ArkUI';

const POSTER_PX: number = 230;
const LATTICE_SRC_PX: number = 60;

class PosterRenderNode extends RenderNode {
  // Animation state (driven by displaySync via the controller).
  private dashPhase: number = 0;
  private rotationDeg: number = 0;
  private frameCounter: number = 0;

  private latticePix: image.PixelMap | null = null;

  setAnimationState(dashPhase: number, rotationDeg: number, frame: number): void {
    this.dashPhase = dashPhase;
    this.rotationDeg = rotationDeg;
    this.frameCounter = frame;
  }

  draw(context: DrawContext): void {
    const canvas: drawing.Canvas = context.canvas;

    canvas.drawColor(0xFFFFFFFF);

    const outer: common2D.Rect = drawing.RectUtils.makeLtrb(0, 0, POSTER_PX, POSTER_PX);
    const frame: common2D.Rect = drawing.RectUtils.makeCopy(outer);
    drawing.RectUtils.inset(frame, 10, 10, 10, 10);

    const headerHeight: number = Math.round(drawing.RectUtils.getHeight(frame) * 0.32);
    const header: common2D.Rect = drawing.RectUtils.makeLtrb(
      frame.left, frame.top, frame.right, frame.top + headerHeight
    );

    const content: common2D.Rect = drawing.RectUtils.makeCopy(frame);
    drawing.RectUtils.inset(content, 6, headerHeight + 4, 6, 6);
    drawing.RectUtils.intersect(content, frame);

    const cornerRadius: number = 14;

    const startPt: common2D.Point = { x: content.left, y: content.top };
    const endPt: common2D.Point = { x: content.right, y: content.bottom };
    const gradColors: number[] = [0xFF1A1F3A, 0xFFEF476F, 0xFFFFD166];
    const gradStops: number[] = [0.0, 0.55, 1.0];
    const linearShader: drawing.ShaderEffect = drawing.ShaderEffect.createLinearGradient(
      startPt, endPt, gradColors, drawing.TileMode.CLAMP, gradStops, null
    );

    const shadowColor: common2D.Color = { alpha: 140, red: 0, green: 0, blue: 0 };
    const shadowLayer: drawing.ShadowLayer = drawing.ShadowLayer.create(
      6.0, 0.0, 3.0, shadowColor
    );

    const maskFilter: drawing.MaskFilter = drawing.MaskFilter.createBlurMaskFilter(
      drawing.BlurType.NORMAL, 1.5
    );
    const imageFilter: drawing.ImageFilter = drawing.ImageFilter.createBlurImageFilter(
      2.0, 2.0, drawing.TileMode.CLAMP, null
    );

    const dashIntervals: number[] = [4, 3];
    const dashEffect: drawing.PathEffect = drawing.PathEffect.createDashPathEffect(
      dashIntervals, this.dashPhase
    );
    const cornerEffect: drawing.PathEffect = drawing.PathEffect.createCornerPathEffect(2);
    const composedEffect: drawing.PathEffect = drawing.PathEffect.createComposePathEffect(
      dashEffect, cornerEffect
    );

    const roundFrame: drawing.RoundRect = new drawing.RoundRect(frame, cornerRadius, cornerRadius);
    roundFrame.setCorner(drawing.CornerPos.TOP_LEFT_POS, cornerRadius, cornerRadius);
    roundFrame.offset(0, 0);

    const bodyRegion: drawing.Region = new drawing.Region();
    bodyRegion.setRect(content.left, content.top, content.right, content.bottom);
    const headerRegion: drawing.Region = new drawing.Region();
    headerRegion.setRect(header.left, header.top, header.right, header.bottom);
    bodyRegion.op(headerRegion, drawing.RegionOp.UNION);

    const bgBrush: drawing.Brush = new drawing.Brush();
    bgBrush.setAntiAlias(false);
    bgBrush.setColor(255, 245, 247, 255);
    bgBrush.setShadowLayer(shadowLayer);
    bgBrush.setShaderEffect(linearShader);
    canvas.attachBrush(bgBrush);
    canvas.drawRoundRect(roundFrame);
    canvas.detachBrush();

    canvas.save();
    canvas.clipRegion(bodyRegion, drawing.ClipOp.INTERSECT);

    const badgeBrush: drawing.Brush = new drawing.Brush();
    badgeBrush.setColor(170, 255, 255, 255);
    badgeBrush.setMaskFilter(maskFilter);
    canvas.attachBrush(badgeBrush);
    const headerCx: number = drawing.RectUtils.centerX(header);
    const headerCy: number = drawing.RectUtils.centerY(header);
    const badgeRadius: number = Math.min(
      drawing.RectUtils.getWidth(header), drawing.RectUtils.getHeight(header)
    ) * 0.4;
    canvas.drawCircle(headerCx, headerCy, badgeRadius);
    canvas.detachBrush();

    const promoStrip: common2D.Rect = drawing.RectUtils.makeLtrb(
      content.left, content.top, content.right, content.top + 12
    );
    const blurBrush: drawing.Brush = new drawing.Brush();
    blurBrush.setColor(180, 255, 209, 102);
    blurBrush.setImageFilter(imageFilter);
    canvas.attachBrush(blurBrush);
    canvas.drawRect(promoStrip);
    canvas.detachBrush();

    const starPath: drawing.Path = PosterRenderNode.buildStarPath(
      headerCx, headerCy, badgeRadius * 0.9, 5
    );
    const starBrush: drawing.Brush = new drawing.Brush();
    starBrush.setColor(255, 255, 224, 102);
    canvas.attachBrush(starBrush);
    canvas.drawPath(starPath);
    canvas.detachBrush();

    const iterator: drawing.PathIterator = new drawing.PathIterator(starPath);
    const tickBrush: drawing.Brush = new drawing.Brush();
    tickBrush.setColor(255, 27, 34, 56);
    canvas.attachBrush(tickBrush);
    const VERB_DONE: drawing.PathIteratorVerb = drawing.PathIteratorVerb.DONE;
    const VERB_CLOSE: drawing.PathIteratorVerb = drawing.PathIteratorVerb.CLOSE;
    while (iterator.hasNext()) {
      const buf: common2D.Point[] = [
        { x: 0, y: 0 }, { x: 0, y: 0 }, { x: 0, y: 0 }, { x: 0, y: 0 }
      ];
      const verb: drawing.PathIteratorVerb = iterator.next(buf, 0);
      if (verb === VERB_DONE || verb === VERB_CLOSE) {
        break;
      }
      canvas.drawCircle(buf[0].x, buf[0].y, 1.2);
    }
    canvas.detachBrush();

    const rotMatrix: drawing.Matrix = new drawing.Matrix();
    rotMatrix.setRotation(this.rotationDeg, headerCx, headerCy);
    canvas.save();
    canvas.concatMatrix(rotMatrix);
    const headFont: drawing.Font = new drawing.Font();
    headFont.setSize(11);
    const headBlob: drawing.TextBlob = drawing.TextBlob.makeFromString(
      'NEXT', headFont, drawing.TextEncoding.TEXT_ENCODING_UTF8
    );
    const headTextBrush: drawing.Brush = new drawing.Brush();
    headTextBrush.setColor(255, 27, 34, 56);
    canvas.attachBrush(headTextBrush);
    canvas.drawTextBlob(headBlob, headerCx - 12, headerCy + 4);
    canvas.detachBrush();
    canvas.restore();

    const bodyFont: drawing.Font = new drawing.Font();
    bodyFont.setSize(9);
    const bodyBrush: drawing.Brush = new drawing.Brush();
    bodyBrush.setColor(255, 255, 255, 255);
    canvas.attachBrush(bodyBrush);
    canvas.drawTextBlob(
      drawing.TextBlob.makeFromString('Promo', bodyFont, drawing.TextEncoding.TEXT_ENCODING_UTF8),
      content.left + 4, content.top + 22
    );
    canvas.drawTextBlob(
      drawing.TextBlob.makeFromString(`Frame ${this.frameCounter}`, bodyFont, drawing.TextEncoding.TEXT_ENCODING_UTF8),
      content.left + 4, content.top + 34
    );
    canvas.drawTextBlob(
      drawing.TextBlob.makeFromString('ArkGraphics2D', bodyFont, drawing.TextEncoding.TEXT_ENCODING_UTF8),
      content.left + 4, content.top + 46
    );
    canvas.detachBrush();

    canvas.restore(); // pop region clip

    const borderPen: drawing.Pen = new drawing.Pen();
    borderPen.setStrokeWidth(1.5);
    borderPen.setAntiAlias(true);
    borderPen.setColor(204, 27, 34, 56);
    borderPen.setPathEffect(composedEffect);
    canvas.attachPen(borderPen);
    canvas.drawRoundRect(roundFrame);
    canvas.detachPen();

    if (this.latticePix === null) {
      this.latticePix = PosterRenderNode.buildLatticePixelMap();
    }
    const latticeXDivs: number[] = [12, 48];
    const latticeYDivs: number[] = [12, 48];
    const latticeBounds: common2D.Rect = drawing.RectUtils.makeLtrb(
      0, 0, LATTICE_SRC_PX, LATTICE_SRC_PX
    );
    const lattice: drawing.Lattice = drawing.Lattice.createImageLattice(
      latticeXDivs, latticeYDivs, latticeXDivs.length, latticeYDivs.length,
      latticeBounds, null, null as Array<number> | null
    );
    const latticeDst: common2D.Rect = drawing.RectUtils.makeLtrb(
      frame.left + 6, frame.bottom - 18, frame.right - 6, frame.bottom - 4
    );
    canvas.drawImageLattice(this.latticePix, lattice, latticeDst, drawing.FilterMode.FILTER_MODE_NEAREST);
  }

  // ---- helpers --------------------------------------------------------------
  private static buildStarPath(cx: number, cy: number, radius: number, points: number): drawing.Path {
    const path: drawing.Path = new drawing.Path();
    const inner: number = radius * 0.45;
    const step: number = Math.PI / points;
    let angle: number = -Math.PI / 2;
    path.moveTo(cx + radius * Math.cos(angle), cy + radius * Math.sin(angle));
    for (let i: number = 0; i < points * 2; i++) {
      angle += step;
      const r: number = (i % 2 === 0) ? inner : radius;
      path.lineTo(cx + r * Math.cos(angle), cy + r * Math.sin(angle));
    }
    path.close();
    return path;
  }

  /**
   * Build a 60×60 RGBA pixel map split into a 3×3 grid of solid colours so
   * the nine-patch lattice draw demonstrably stretches the centre cells while
   * leaving the corner cells fixed-size.
   */
  private static buildLatticePixelMap(): image.PixelMap {
    const w: number = LATTICE_SRC_PX;
    const h: number = LATTICE_SRC_PX;
    const buffer: ArrayBuffer = new ArrayBuffer(w * h * 4);
    const view: Uint8Array = new Uint8Array(buffer);
    // Palette indexed by (column, row) of the 3x3 grid (split at 12 / 48).
    const palette: number[][] = [
      [0x06, 0xD6, 0xA0], [0xFF, 0xD1, 0x66], [0x11, 0x8A, 0xB2],
      [0xEF, 0x47, 0x6F], [0x07, 0x3B, 0x4C], [0xF7, 0x8C, 0x6B],
      [0x84, 0x33, 0xC4], [0x2E, 0xC4, 0xB6], [0xFE, 0xE4, 0x40]
    ];
    for (let y: number = 0; y < h; y++) {
      const row: number = (y < 12) ? 0 : (y < 48 ? 1 : 2);
      for (let x: number = 0; x < w; x++) {
        const col: number = (x < 12) ? 0 : (x < 48 ? 1 : 2);
        const c: number[] = palette[row * 3 + col];
        const idx: number = (y * w + x) * 4;
        view[idx + 0] = c[0];
        view[idx + 1] = c[1];
        view[idx + 2] = c[2];
        view[idx + 3] = 255;
      }
    }
    const opts: image.InitializationOptions = {
      size: { width: w, height: h },
      pixelFormat: image.PixelMapFormat.RGBA_8888,
      editable: false
    };
    return image.createPixelMapSync(buffer, opts);
  }
}

export class PosterNodeController extends NodeController {
  private root: FrameNode | null = null;
  private posterNode: PosterRenderNode = new PosterRenderNode();

  makeNode(uiContext: UIContext): FrameNode | null {
    this.root = new FrameNode(uiContext);
    const rootRender: RenderNode | null = this.root.getRenderNode();
    if (rootRender !== null) {
      rootRender.clipToFrame = true;
      rootRender.size = { width: POSTER_PX, height: POSTER_PX };
      this.posterNode.frame = { x: 0, y: 0, width: POSTER_PX, height: POSTER_PX };
      rootRender.appendChild(this.posterNode);
    }
    return this.root;
  }

  /** Push new animation state and ask the render node to repaint. */
  tick(dashPhase: number, rotationDeg: number, frameCounter: number): void {
    this.posterNode.setAnimationState(dashPhase, rotationDeg, frameCounter);
    this.posterNode.invalidate();
  }
}

export const POSTER_SIZE_PX: number = POSTER_PX;
