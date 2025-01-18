document.getElementById("sendFile").addEventListener("click", () => {
    const fileInput = document.getElementById("fileInput");
    if (fileInput.files.length === 0) {
      alert("Please select a file!");
      return;
    }
    const file = fileInput.files[0];
    console.log("File selected:", file.name);
    // Placeholder for WebRTC or backend API call
  });
  