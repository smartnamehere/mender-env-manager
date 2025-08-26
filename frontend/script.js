const createEnvBtn = document.getElementById('create-env');
const environmentsList = document.getElementById('environments');

const API_URL = 'YOUR_API_GATEWAY_URL'; // This will be replaced by Terraform

const getEnvironments = async () => {
  const response = await fetch(`${API_URL}/environments`);
  const environments = await response.json();

  environmentsList.innerHTML = '';

  environments.forEach(env => {
    const li = document.createElement('li');
    li.className = 'list-group-item d-flex justify-content-between align-items-center';
    li.innerHTML = `
      <div>
        <a href="${env.url}" target="_blank">${env.id}</a>
      </div>
      <button class="take-down btn btn-danger btn-sm" data-id="${env.id}">Take down</button>
    `;
    environmentsList.appendChild(li);
  });
};

const createEnvironment = async () => {
  await fetch(`${API_URL}/environments`, { method: 'POST' });
  getEnvironments();
};

const takeDownEnvironment = async (id) => {
  await fetch(`${API_URL}/environments/${id}`, { method: 'DELETE' });
  getEnvironments();
};

createEnvBtn.addEventListener('click', createEnvironment);

environmentsList.addEventListener('click', (event) => {
  if (event.target.classList.contains('take-down')) {
    const id = event.target.dataset.id;
    takeDownEnvironment(id);
  }
});

getEnvironments();
setInterval(getEnvironments, 5000);