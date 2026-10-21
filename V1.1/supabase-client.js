(function () {
  const config = window.SUPABASE_CONFIG;
  if (!config || !config.url || !config.publishableKey) {
    throw new Error('Supabase configuration is missing. Check supabase-config.js.');
  }
  if (!window.supabase || typeof window.supabase.createClient !== 'function') {
    throw new Error('Supabase SDK failed to load.');
  }

  const client = window.supabase.createClient(config.url, config.publishableKey);

  async function getProfile(user) {
    const { data, error } = await client
      .from('profiles')
      .select('id, full_name, email, phone, role, is_verified, created_at')
      .eq('id', user.id)
      .single();
    if (error) throw error;
    return data;
  }

  async function requireUser(options) {
    const settings = options || {};
    const { data, error } = await client.auth.getSession();
    if (error) throw error;
    if (!data.session) {
      window.location.href = 'login.html';
      return null;
    }

    const profile = await getProfile(data.session.user);
    if (settings.admin && profile.role !== 'admin') {
      window.location.href = 'login.html';
      return null;
    }
    return { user: data.session.user, profile: profile };
  }

  window.richersDb = {
    client: client,
    getProfile: getProfile,
    requireUser: requireUser
  };

  const adminLogoutLink = document.getElementById('adminLogoutLink');
  if (adminLogoutLink) {
    adminLogoutLink.addEventListener('click', async function (event) {
      event.preventDefault();
      if (!window.confirm('Are you sure you want to log out?')) return;
      try {
        const { error } = await client.auth.signOut();
        if (error) throw error;
        window.location.href = 'login.html';
      } catch (error) {
        console.error('Admin logout failed:', error);
        alert('Logout failed. Please try again.');
      }
    });
  }
})();
