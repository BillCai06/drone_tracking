import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "nms_ext"))
import nms_ext as _ext
import torch
from box_utils import TrackedBox

def custom_nms(boxes, scores, iou_threshold=0.45):
    return _ext.nms_cuda(
        boxes.float().contiguous(),
        scores.float().contiguous(),
        iou_threshold
    ).bool()

def custom_soft_nms(boxes, scores, sigma=0.5, score_threshold=0.05):
    return _ext.soft_nms_cuda(
        boxes.float().contiguous(),
        scores.float().contiguous(),
        sigma, score_threshold
    )

@torch.inference_mode()
def get_best_detection_custom_nms(
    detector, image_path, conf, iou, class_id, device,
    trackerModule, use_track=True,
    use_soft_nms=False, soft_nms_sigma=0.5,
):
    if use_track:
        results = detector.track(
            source=image_path, conf=conf, iou=1.0,
            device=device, tracker=trackerModule,
            persist=True, verbose=False
        )
    else:
        results = detector.predict(
            source=image_path, conf=conf, iou=1.0,
            device=device, verbose=False
        )

    r0 = results[0]
    if r0.boxes is None or len(r0.boxes) == 0:
        return None, "none"

    boxes_xyxy = r0.boxes.xyxy.float().cuda()
    scores_all  = r0.boxes.conf.float().cuda()
    classes     = r0.boxes.cls.cuda()

    if class_id is not None:
        mask = classes == class_id
        if mask.sum() == 0:
            return None, "none"
        boxes_xyxy = boxes_xyxy[mask]
        scores_all  = scores_all[mask]
        ids = torch.where(mask)[0]
    else:
        ids = torch.arange(len(classes), device=classes.device)

    if use_soft_nms:
        decayed = custom_soft_nms(boxes_xyxy, scores_all.clone(),
                                  sigma=soft_nms_sigma, score_threshold=conf)
        keep_mask = decayed >= conf
        if keep_mask.sum() == 0:
            return None, "none"
        keep_indices = torch.where(keep_mask)[0]
        best_local = decayed[keep_mask].argmax()
        best_i = ids[keep_indices[best_local]].item()
    else:
        keep_mask = custom_nms(boxes_xyxy, scores_all, iou_threshold=iou)
        if keep_mask.sum() == 0:
            return None, "none"
        keep_indices = torch.where(keep_mask)[0]
        best_local = scores_all[keep_indices].argmax()
        best_i = ids[keep_indices[best_local]].item()

    box = r0.boxes[best_i]
    x1, y1, x2, y2 = box.xyxy[0].tolist()
    h_orig, w_orig = r0.orig_shape

    return TrackedBox(
        cls=int(box.cls[0]),
        cx=(x1 + x2) / 2.0 / w_orig,
        cy=(y1 + y2) / 2.0 / h_orig,
        w=(x2 - x1) / w_orig,
        h=(y2 - y1) / h_orig,
        conf=float(box.conf[0]),
        track_id=int(box.id[0]) if hasattr(box, "id") and box.id is not None else None
    ), "det"