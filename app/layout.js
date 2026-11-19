import './globals.css';
import Nav from '@/components/Nav';

export const metadata = { title: 'Back2You - Lost item return', description: 'Track a found item from discovery to verified return.' };
export default function RootLayout({ children }) {
  return <html lang="en"><body><Nav /><main>{children}</main></body></html>;
}
