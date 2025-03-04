from flask import Flask, request, Response, render_template_string
import csv
import io

app = Flask(__name__)

HTML_PAGE = '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>CSV Filter Web Application</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 50px; }
    #drop-area {
      border: 2px dashed #ccc;
      border-radius: 20px;
      width: 100%;
      max-width: 500px;
      margin: 0 auto;
      padding: 20px;
      text-align: center;
    }
    #drop-area.highlight {
      border-color: purple;
    }
    #fileElem {
      display: none;
    }
    #gender {
      margin-top: 20px;
    }
    #submitBtn {
      margin-top: 20px;
      padding: 10px 20px;
      font-size: 16px;
    }
  </style>
</head>
<body>
  <h1>CSV Filter Web Application</h1>
  <div id="drop-area">
    <form id="upload-form" method="POST" enctype="multipart/form-data">
      <p>Drag & drop your CSV file here or <label for="fileElem" style="color: blue; text-decoration: underline; cursor: pointer;">browse</label></p>
      <input type="file" id="fileElem" name="file" accept=".csv">
      <div id="gender">
        <label for="genderSelect">Select Gender:</label>
        <select name="gender" id="genderSelect">
          <option value="Male">Male</option>
          <option value="Female">Female</option>
        </select>
      </div>
      <button type="submit" id="submitBtn">Filter CSV</button>
    </form>
  </div>

  <script>
    let dropArea = document.getElementById('drop-area');

    // Prevent default behaviors
    ['dragenter', 'dragover', 'dragleave', 'drop'].forEach(eventName => {
      dropArea.addEventListener(eventName, preventDefaults, false)
      document.body.addEventListener(eventName, preventDefaults, false)
    });

    function preventDefaults (e) {
      e.preventDefault();
      e.stopPropagation();
    }

    // Highlight drop area when item is dragged over it
    ['dragenter', 'dragover'].forEach(eventName => {
      dropArea.addEventListener(eventName, () => dropArea.classList.add('highlight'), false)
    });
    ['dragleave', 'drop'].forEach(eventName => {
      dropArea.addEventListener(eventName, () => dropArea.classList.remove('highlight'), false)
    });

    // Handle dropped files
    dropArea.addEventListener('drop', handleDrop, false);

    function handleDrop(e) {
      let dt = e.dataTransfer;
      let files = dt.files;
      if(files.length > 0) {
        document.getElementById('fileElem').files = files;
      }
    }
  </script>
</body>
</html>
'''

def filter_csv(file_stream, gender):
    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow(["Name", "Designation"])
    file_stream.seek(0)
    reader = csv.DictReader(io.StringIO(file_stream.read().decode("utf-8")))
    for row in reader:
        if row["Gender"].strip().lower() == gender.strip().lower():
            writer.writerow([row["Name"], row["Designation"]])
    output.seek(0)
    return output

@app.route("/", methods=["GET", "POST"])
def index():
    if request.method == "POST":
        if "file" not in request.files:
            return "No file provided", 400
        file = request.files["file"]
        if file.filename == "":
            return "No file selected", 400

        gender = request.form.get("gender")
        if gender not in ["Male", "Female"]:
            return "Invalid gender selection", 400

        csv_output = filter_csv(file.stream, gender)
        return Response(
            csv_output.getvalue(),
            mimetype="text/csv",
            headers={"Content-Disposition": f"attachment;filename=filtered_{gender}.csv"}
        )
    return render_template_string(HTML_PAGE)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=80)
