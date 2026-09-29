import UIKit

/// 渲染器独占、仅主线程使用。按类型和绘制顺序复用；每帧结束释放未使用对象，
/// 不把一次密集场景的峰值数量永久留在内存里。对象身份不参与系列/命中语义。
final class CartesianRenderObjectPool {
    private final class Storage<Object: AnyObject> {
        var objects: [Object] = []
        var used = 0
        var created = 0
        var reused = 0

        func begin(reusing: Bool) {
            if !reusing { objects.removeAll() }
            used = 0; created = 0; reused = 0
        }

        func take(make: () -> Object, reset: (Object) -> Void) -> Object {
            let object: Object
            if used < objects.count {
                object = objects[used]
                reset(object)
                reused += 1
            } else {
                object = make()
                objects.append(object)
                created += 1
            }
            used += 1
            return object
        }

        func end(discard: (Object) -> Void) {
            objects.dropFirst(used).forEach(discard)
            objects.removeLast(objects.count - used)
        }
    }

    private let shapes = Storage<CAShapeLayer>()
    private let gradients = Storage<CAGradientLayer>()
    private let texts = Storage<CATextLayer>()
    private let layers = Storage<CALayer>()
    private let labels = Storage<UILabel>()

    /// 内部诊断：最近一帧创建/复用数量，测试与性能采样使用。
    var createdCount: Int { shapes.created + gradients.created + texts.created + layers.created + labels.created }
    var reusedCount: Int { shapes.reused + gradients.reused + texts.reused + layers.reused + labels.reused }
    var retainedCount: Int { shapes.objects.count + gradients.objects.count + texts.objects.count + layers.objects.count + labels.objects.count }

    func begin(reusing: Bool) {
        // mask 不在 sublayers 中；先解除旧关联，避免旧渐变持有下一帧的线/标记。
        for gradient in gradients.objects { gradient.mask = nil }
        if !reusing { detachAll() }
        shapes.begin(reusing: reusing); gradients.begin(reusing: reusing)
        texts.begin(reusing: reusing); layers.begin(reusing: reusing); labels.begin(reusing: reusing)
    }

    func end() {
        shapes.end { $0.removeFromSuperlayer() }; gradients.end { $0.removeFromSuperlayer(); $0.mask = nil }
        texts.end { $0.removeFromSuperlayer() }; layers.end { $0.removeFromSuperlayer() }
        labels.end { $0.removeFromSuperview() }
    }

    func clear() { begin(reusing: false) }

    private func detachAll() {
        // 也用于 unmount；系列注释层可能位于 root 的子容器中。
        for layer in shapes.objects { layer.removeFromSuperlayer(); layer.mask = nil }
        for layer in gradients.objects { layer.removeFromSuperlayer(); layer.mask = nil }
        for layer in texts.objects { layer.removeFromSuperlayer() }
        for layer in layers.objects { layer.removeFromSuperlayer() }
        for label in labels.objects { label.removeFromSuperview() }
    }

    func shape() -> CAShapeLayer {
        shapes.take(make: { CAShapeLayer() }) { layer in
            self.resetLayer(layer)
            // 每个绘制点完整覆盖 path/fill/stroke；这里只清理可选状态。
            // 避免对成千上万的 marker 反复写入相同默认值。
            if layer.lineWidth != 1 { layer.lineWidth = 1 }
            if layer.lineCap != .butt { layer.lineCap = .butt }
            if layer.lineJoin != .miter { layer.lineJoin = .miter }
            if layer.lineDashPattern != nil { layer.lineDashPattern = nil }
            if layer.strokeEnd != 1 { layer.strokeEnd = 1 }
        }
    }

    func gradient() -> CAGradientLayer {
        gradients.take(make: { CAGradientLayer() }, reset: resetLayer)
    }

    func text() -> CATextLayer {
        texts.take(make: { CATextLayer() }, reset: resetLayer)
    }

    func layer() -> CALayer {
        layers.take(make: { CALayer() }, reset: resetLayer)
    }

    func label() -> UILabel {
        labels.take(make: { UILabel() }) { label in
            // 先归零 transform 再量尺寸，否则旋转刻度切换回普通标签时位置错误。
            label.transform = .identity
            label.bounds = .zero
        }
    }

    /// 仅重置本模块实际会改动的状态；路径/文字/颜色随后由对应绘制函数覆盖。
    private func resetLayer(_ layer: CALayer) {
        if layer.animationKeys() != nil { layer.removeAllAnimations() }
        if layer.mask != nil { layer.mask = nil }
        if layer.bounds != .zero { layer.bounds = .zero }
        if layer.position != .zero { layer.position = .zero }
        if layer.shadowOpacity != 0 { layer.shadowOpacity = 0 }
        if layer.shadowPath != nil { layer.shadowPath = nil }
    }
}
