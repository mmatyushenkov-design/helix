from fastapi import FastAPI

app = FastAPI(title="Helix API", version="1.0.0")

@app.get("/")
def read_root():
    return {"message": "Welcome to Helix API (5/3/1 Periodization)"}
