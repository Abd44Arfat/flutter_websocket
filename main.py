# --- Python Backend: FastAPI with LSTM model ---
# Save this as app.py

from fastapi import FastAPI, File, UploadFile, HTTPException, WebSocket
from fastapi.responses import JSONResponse
import numpy as np
import cv2
from tensorflow.keras.models import load_model
import mediapipe as mp
import uvicorn
from pydantic import BaseModel
import tensorflow as tf

app = FastAPI()

# Load your LSTM model
model = tf.keras.models.load_model("LSTM_model_97(2).h5")

# Define the expected input shape
SEQUENCE_LENGTH = 30
KEYPOINTS_DIM = 126  # 21*3*2 (left+right hand, x/y/z)

class KeypointsRequest(BaseModel):
    sequence: list  # List of 30 frames, each frame is a list of 126 floats

actions = ["nice", "thankyou", "meet", "fine", "how", "what", "cool", "name", "hello", "you", "me", "your"]

mp_holistic = mp.solutions.holistic


def extract_keypoints(results):
    left_hand = np.array([[res.x, res.y, res.z] for res in results.left_hand_landmarks.landmark]).flatten() \
        if results.left_hand_landmarks else np.zeros(21*3)
    right_hand = np.array([[res.x, res.y, res.z] for res in results.right_hand_landmarks.landmark]).flatten() \
        if results.right_hand_landmarks else np.zeros(21*3)
    return np.concatenate([left_hand, right_hand])


@app.post("/predict")
def predict_keypoints(data: KeypointsRequest):
    sequence = np.array(data.sequence)
    if sequence.shape != (SEQUENCE_LENGTH, KEYPOINTS_DIM):
        raise HTTPException(status_code=400, detail="Invalid input shape")
    sequence = np.expand_dims(sequence, axis=0)  # Shape: (1, 30, 126)
    res = model.predict(sequence)[0]
    predicted_index = int(np.argmax(res))
    confidence = float(np.max(res))
    return {"predicted_index": predicted_index, "confidence": confidence}

@app.websocket("/ws/predict")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    sequence = []
    while True:
        data = await websocket.receive_json()
        keypoints = np.array(data["keypoints"])  # expects a list of 126 floats
        sequence.append(keypoints)
        sequence = sequence[-SEQUENCE_LENGTH:]
        if len(sequence) == SEQUENCE_LENGTH:
            input_seq = np.expand_dims(np.array(sequence), axis=0)
            res = model.predict(input_seq)[0]
            predicted_index = int(np.argmax(res))
            confidence = float(np.max(res))
            await websocket.send_json({
                "predicted_index": predicted_index,
                "action": actions[predicted_index],
                "confidence": confidence
            })

# Uncomment below line if you want to run this directly
if __name__ == "__main__":
    uvicorn.run("app:app", host="0.0.0.0", port=8000, reload=True)
