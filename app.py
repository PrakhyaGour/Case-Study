from flask import Flask
app = Flask(__name__)

@app.route("/")
def hello():
    return "Hello world of Kubernetes with flux!!!!!! check if it is working"

if __name__ == "__main__":
    app.run(debug=True,host='0.0.0.0', port=8000)
