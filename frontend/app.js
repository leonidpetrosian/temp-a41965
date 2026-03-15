document.addEventListener('DOMContentLoaded', () => {
    const tabs = document.querySelectorAll('.tab');
    const tabContents = document.querySelectorAll('.tab-content');
    const statusIndicator = document.getElementById('status-indicator');
    
    // Auth State
    let authToken = localStorage.getItem('vpn_token') || null;

    // Initialize UI based on auth state
    function updateUI() {
        if (authToken) {
            document.getElementById('dashboard-tab').style.display = 'block';
            document.getElementById('tab-btn-register').style.display = 'none';
            document.getElementById('tab-btn-login').style.display = 'none';
            switchTab('dashboard');
            document.getElementById('token-display').textContent = authToken.substring(0, 20) + '...';
        } else {
            document.getElementById('dashboard-tab').style.display = 'none';
            document.getElementById('tab-btn-register').style.display = 'block';
            document.getElementById('tab-btn-login').style.display = 'block';
            switchTab('login');
        }
    }

    // Tab Switching
    function switchTab(tabId) {
        tabs.forEach(t => {
            if (t.dataset.tab === tabId) {
                t.classList.add('active');
            } else {
                t.classList.remove('active');
            }
        });
        tabContents.forEach(tc => {
            if (tc.id === tabId) {
                tc.classList.add('active');
            } else {
                tc.classList.remove('active');
            }
        });
    }

    tabs.forEach(tab => {
        tab.addEventListener('click', () => {
            if (tab.style.display !== 'none') {
                 switchTab(tab.dataset.tab);
            }
        });
    });

    // API Health Check
    async function checkHealth() {
        try {
            const res = await fetch('/health');
            if (res.ok) {
                statusIndicator.textContent = 'API Online';
                statusIndicator.className = 'status online';
            } else {
                throw new Error('Not OK');
            }
        } catch (err) {
            statusIndicator.textContent = 'API Offline';
            statusIndicator.className = 'status offline';
        }
    }
    checkHealth();
    setInterval(checkHealth, 10000);

    // Helpers
    function showMsg(elementId, text, isError = false) {
        const el = document.getElementById(elementId);
        el.textContent = text;
        el.className = 'msg ' + (isError ? 'error' : 'success');
        setTimeout(() => { el.textContent = ''; }, 5000);
    }

    async function apiCall(endpoint, method, body = null, requireAuth = false) {
        const headers = { 'Content-Type': 'application/json' };
        if (requireAuth && authToken) {
            headers['Authorization'] = 'Bearer ' + authToken;
        }

        const options = { method, headers };
        if (body) options.body = JSON.stringify(body);

        const res = await fetch(endpoint, options);
        let data;
        try {
            data = await res.json();
        } catch {
            data = { error: 'Failed to parse response' };
        }
        
        if (!res.ok) throw new Error(data.error || 'API Error');
        return data;
    }

    // Register
    document.getElementById('register-form').addEventListener('submit', async (e) => {
        e.preventDefault();
        const email = document.getElementById('reg-email').value;
        const password = document.getElementById('reg-password').value;
        
        try {
            await apiCall('/auth/register', 'POST', { email, password });
            showMsg('reg-msg', 'Registration successful! Please login.');
            setTimeout(() => switchTab('login'), 2000);
        } catch (err) {
            showMsg('reg-msg', err.message, true);
        }
    });

    // Login
    document.getElementById('login-form').addEventListener('submit', async (e) => {
        e.preventDefault();
        const email = document.getElementById('log-email').value;
        const password = document.getElementById('log-password').value;
        
        try {
            const data = await apiCall('/auth/login', 'POST', { email, password });
            authToken = data.token;
            localStorage.setItem('vpn_token', authToken);
            showMsg('log-msg', 'Login successful!');
            updateUI();
        } catch (err) {
            showMsg('log-msg', err.message, true);
        }
    });

    // Dashboard Actions
    document.getElementById('btn-logout').addEventListener('click', () => {
        authToken = null;
        localStorage.removeItem('vpn_token');
        updateUI();
    });

    document.getElementById('btn-connect').addEventListener('click', async () => {
        try {
            const data = await apiCall('/user/connect', 'POST', {}, true);
            showMsg('dash-msg', 'Connect: ' + JSON.stringify(data));
        } catch (err) {
            showMsg('dash-msg', err.message, true);
        }
    });

    document.getElementById('btn-config').addEventListener('click', async () => {
        try {
            const data = await apiCall('/user/config/test-peer-id', 'GET', null, true);
            showMsg('dash-msg', 'Config: ' + JSON.stringify(data));
        } catch (err) {
            showMsg('dash-msg', err.message, true);
        }
    });

    updateUI();
});
