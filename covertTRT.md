BLIPSEG_SITE="/opt/miniforge/envs/blipseg/lib/python3.8/site-packages"
PYTHONNOUSERSITE=1 \
LD_LIBRARY_PATH="${BLIPSEG_SITE}/torch/lib:/usr/local/cuda/lib64:/usr/lib/aarch64-linux-gnu" \
PYTHONPATH="${BLIPSEG_SITE}:/usr/lib/python3.8/dist-packages:/usr/local/lib/python3.8/dist-packages" \
/opt/miniforge/envs/yolo_tracking/bin/python -W ignore -c "
from ultralytics import YOLO
model = YOLO('/home/zd/tracking_ws/src/Scout-Vision/yolo26n_neo_720_v3.pt')
model.export(format='engine', imgsz=720, device=0, half=True, simplify=True)
print('Done.')
"