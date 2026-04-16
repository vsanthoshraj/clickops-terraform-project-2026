const form = document.getElementById('uploadForm');
const cancelBtn = document.getElementById('cancelBtn');
const submitBtn = document.getElementById('submitBtn');
const messageDiv = document.getElementById('message');

// For local testing logic, using localhost:3000
// For local testing logic, using localhost:3000 or relative url
const BACKEND_URL = ''; 

form.addEventListener('submit', async (e) => {
    e.preventDefault();
    showMessage('', ''); // Clear previous message
    
    const name = document.getElementById('name').value.trim();
    const age = document.getElementById('age').value;
    const imageInput = document.getElementById('image');
    const image = imageInput.files[0];

    // Frontend Basic Validation
    if (!name || !age || !image) {
        showMessage('All fields are required.', 'error');
        return;
    }

    if (!image.type.startsWith('image/')) {
        showMessage('Please upload a valid image file formatting.', 'error');
        return;
    }

    // Set buttons to processing state
    submitBtn.textContent = 'UPLOADING...';
    submitBtn.disabled = true;
    cancelBtn.disabled = true;

    const formData = new FormData();
    formData.append('name', name);
    formData.append('age', age);
    formData.append('image', image);

    try {
        const response = await fetch(`${BACKEND_URL}/upload`, {
            method: 'POST',
            body: formData,
        });

        const result = await response.json();

        if (response.ok) {
            showMessage(result.message || 'Upload successful!', 'success');
            form.reset();
        } else {
            showMessage(result.error || 'Upload failed due to an error.', 'error');
        }
    } catch (error) {
        showMessage('Network error. Is the backend running on port 3000?', 'error');
        console.error('Upload Request Error:', error);
    } finally {
        // Reset processing state
        submitBtn.textContent = 'SUBMIT';
        submitBtn.disabled = false;
        cancelBtn.disabled = false;
    }
});

// Clear the form and hide error message on Cancel
cancelBtn.addEventListener('click', () => {
    form.reset();
    messageDiv.style.display = 'none';
});

function showMessage(text, type) {
    messageDiv.textContent = text;
    messageDiv.className = `message ${type}`;
    messageDiv.style.display = 'block';
}
