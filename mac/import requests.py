import requests

def download_public_video(url, output_filename):
    # Für öffentlich zugängliche Videos
    response = requests.get(url, stream=True)
    with open(output_filename, 'wb') as f:
        for chunk in response.iter_content(chunk_size=8192):
            if chunk:
                f.write(chunk)

# Beispiel für ein öffentliches Video
url = "https://example.com/public_video.mp4"
download_public_video(url, "video.mp4")