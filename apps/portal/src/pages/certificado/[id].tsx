import { GetServerSideProps } from 'next'
import Head from 'next/head'
import Link from 'next/link'

interface Props {
    certId: string
    studentName?: string
    moduleName?: string
    courseName?: string
    date?: string
    valid: boolean
}

export const getServerSideProps: GetServerSideProps = async ({ params, query }) => {
    const certId = params?.id as string
    // Certificate data is encoded in query params for simple validation
    // In production: look up in MinIO/DB by certId
    return {
        props: {
            certId,
            studentName: (query.name as string) || null,
            moduleName: (query.modulo as string) || null,
            courseName: (query.curso as string) || null,
            date: (query.data as string) || new Date().toLocaleDateString('pt-BR'),
            valid: certId.startsWith('KRV-'),
        }
    }
}

export default function CertificadoPage({ certId, studentName, moduleName, courseName, date, valid }: Props) {
    return (
        <>
            <Head>
                <title>Certificado {certId} — Kreativ Educação</title>
                <meta name="description" content={`Certificado de conclusão emitido pela Kreativ Educação — Código ${certId}`} />
                <link rel="preconnect" href="https://fonts.googleapis.com" />
                <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;800&display=swap" rel="stylesheet" />
            </Head>

            <nav className="navbar">
                <div className="navbar-inner">
                    <Link href="/" className="logo">Kreativ <span>Certificados</span></Link>
                </div>
            </nav>

            <main className="container" style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', minHeight: '80vh' }}>
                {valid ? (
                    <div className="cert-container">
                        <div style={{ fontSize: '48px', marginBottom: '16px' }}>🏆</div>
                        <p className="cert-title">Kreativ Educação</p>
                        <h1 className="cert-h1">Certificado de Conclusão</h1>
                        <p style={{ color: 'var(--text-muted)', marginBottom: '16px' }}>Certificamos que</p>
                        <div className="cert-name">{studentName || 'Aluno(a)'}</div>
                        <p className="cert-info">
                            concluiu com êxito o módulo<br />
                            <strong>{moduleName || '—'}</strong><br />
                            do curso <strong>{courseName || 'Kreativ Educação'}</strong><br />
                            em <strong>{date}</strong>
                        </p>
                        <div style={{ display: 'inline-flex', alignItems: 'center', gap: '8px', background: 'rgba(232,169,0,0.1)', border: '1px solid var(--gold)', padding: '8px 16px', borderRadius: '8px', color: 'var(--gold)', fontSize: '13px' }}>
                            ✅ Certificado Autêntico
                        </div>
                        <div className="cert-id">
                            Código de autenticidade: <strong>{certId}</strong>
                        </div>
                    </div>
                ) : (
                    <div className="centered">
                        <div style={{ fontSize: '48px' }}>❌</div>
                        <h2>Certificado inválido</h2>
                        <p>Não foi possível verificar este certificado. O código pode estar incorreto.</p>
                        <Link href="/" className="btn btn-gold">← Início</Link>
                    </div>
                )}
            </main>
        </>
    )
}
