FROM python
RUN pip install cryptography
COPY tcdicn.py applications/controller.py applications/drone.py applications/inspector.py applications/node.py .
CMD exec python3 $SCRIPT
