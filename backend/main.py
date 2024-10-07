from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from PIL import Image
import io
import base64
import os
import tempfile

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class ImageData(BaseModel):
    image: str

class Detect:
    def __init__(self):
        self.result = 'Xin lỗi, tôi không thể nhận diện bạn'
    
    def detect(self, img):
        # Here you would implement your actual face recognition logic
        # For this example, we'll just return a fixed result
        self.result = 'anh Thua'
        return self.result

detector = Detect()

@app.post("/detect")
async def detect_face(data: ImageData):
    try:
        print(f"Received image data length: {len(data.image)}")
        image_data = base64.b64decode(data.image)
        print(f"Decoded image data length: {len(image_data)}")
        
        img = Image.open(io.BytesIO(image_data))
        print(f"Image size: {img.size}, mode: {img.mode}")
        
        # # Try to save the image in multiple locations
        # locations = [
        #     "received_image.jpg",
        #     "/tmp/received_image.jpg",
        #     os.path.join(tempfile.gettempdir(), "received_image.jpg")
        # ]
        
        # for location in locations:
        #     try:
        #         img.save(location)
        #         print(f"Image saved successfully at {location}")
        #         break
        #     except Exception as save_error:
        #         print(f"Failed to save image at {location}: {str(save_error)}")
        
        result = detector.detect(img)
        return result
    except Exception as e:
        print(f"Error in detect_face: {str(e)}")
        return f"Error processing image: {str(e)}"

@app.get("/")
async def root():
    return {"message": "Welcome to the face detection API"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)