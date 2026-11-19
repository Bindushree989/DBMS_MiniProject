'use client';
import Link from 'next/link';
import { useApi } from '@/components/useApi';
import { Steps } from '@/components/ui';

export default function Home() {
  const { data: k } = useApi('/api/public/stats');
  return (
    <>
      <h1>Found something? Lost something? Let&apos;s get it Back2You.</h1>
      <p className="muted">Every item is tracked from found to returned: who held it, how the owner was verified, and who signed for the handover. The database enforces each step.</p>
      <Steps s="RETURNED" />
      {k && <div className="grid" style={{ marginTop: '1rem' }}>
        <div className="kpi"><b>{k.total_items}</b><span>items reported</span></div>
        <div className="kpi"><b>{k.returned_items}</b><span>returned to owners</span></div>
        <div className="kpi"><b>{k.return_rate_pct}%</b><span>return rate</span></div>
        <div className="kpi"><b>{k.avg_hours_to_return != null ? Math.round(k.avg_hours_to_return / 24 * 10) / 10 : '-'}</b><span>avg. days to return</span></div>
      </div>}
      <p style={{ marginTop: '1.5rem' }}><Link className="btn" href="/lost">I lost something</Link> &nbsp; <Link className="btn" href="/report">I found something</Link></p>
    </>
  );
}
