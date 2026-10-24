import React from 'react';
import { createRoot } from 'react-dom/client';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import '@fontsource/dosis/400.css';
import '@fontsource/dosis/500.css';
import '@fontsource/dosis/600.css';
import '@fontsource/dynapuff/400.css';
import '@fontsource/dynapuff/500.css';
import '@fontsource/dynapuff/600.css';
import App from './App.jsx';
import './index.css';

const queryClient = new QueryClient({
  defaultOptions: { queries: { refetchOnWindowFocus: false, retry: 1 } },
});

createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <QueryClientProvider client={queryClient}>
      <App />
    </QueryClientProvider>
  </React.StrictMode>
);
