"use client";

import { useMemo, useState, type FormEvent } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

type Tab = "in" | "up";
type OAuthProvider = "google" | "github";

export default function AuthPage() {
  const router = useRouter();
  const supabase = useMemo(() => createClient(), []);

  const [tab, setTab] = useState<Tab>("in");
  const [username, setUsername] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [signedUp, setSignedUp] = useState(false);

  const switchTab = (next: Tab) => {
    setTab(next);
    setError(null);
    setSignedUp(false);
  };

  const handleSignIn = async (e: FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError(null);
    const { error } = await supabase.auth.signInWithPassword({
      email,
      password,
    });
    setLoading(false);
    if (error) {
      setError(error.message);
      return;
    }
    router.push("/biblioteca");
  };

  const handleSignUp = async (e: FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError(null);
    const { error } = await supabase.auth.signUp({
      email,
      password,
      options: { data: { username } },
    });
    setLoading(false);
    if (error) {
      setError(error.message);
      return;
    }
    setSignedUp(true);
  };

  const handleOAuth = async (provider: OAuthProvider) => {
    setError(null);
    const { error } = await supabase.auth.signInWithOAuth({
      provider,
      options: { redirectTo: `${window.location.origin}/auth/callback` },
    });
    if (error) setError(error.message);
  };

  return (
    <div className="av-auth-wrap fade-in">
      <div className="auth-card">
        <div className="auth-header">
          <div className="mark"></div>
          <h2 className="neon-cyan">ARCADE VAULT</h2>
          <div
            className="mono"
            style={{
              fontSize: 11,
              color: "var(--ink-faint)",
              letterSpacing: "0.16em",
              marginTop: 6,
            }}
          >
            ACCESO AL SISTEMA · v2.6
          </div>
        </div>

        <div className="auth-tabs">
          <button
            className={tab === "in" ? "on" : ""}
            onClick={() => switchTab("in")}
          >
            INICIAR SESIÓN
          </button>
          <button
            className={tab === "up" ? "on" : ""}
            onClick={() => switchTab("up")}
          >
            CREAR CUENTA
          </button>
        </div>

        {tab === "in" ? (
          <form onSubmit={handleSignIn}>
            <div className="field">
              <label>Correo electrónico</label>
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="jugador@vault.gg"
              />
            </div>
            <div className="field">
              <label>Contraseña</label>
              <input
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="••••••••"
              />
            </div>

            <button
              className="btn lg"
              type="submit"
              disabled={loading}
              style={{ width: "100%", marginTop: 8 }}
            >
              {loading ? "ENTRANDO…" : "ENTRAR AL VAULT"}
            </button>
          </form>
        ) : signedUp ? (
          <div className="toast-saved">
            ▸ REVISA TU CORREO PARA CONFIRMAR LA CUENTA_
          </div>
        ) : (
          <form onSubmit={handleSignUp}>
            <div className="field">
              <label>Usuario</label>
              <input
                value={username}
                onChange={(e) => setUsername(e.target.value)}
                placeholder="px_kai"
              />
            </div>
            <div className="field slide-in">
              <label>Correo electrónico</label>
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="jugador@vault.gg"
              />
            </div>
            <div className="field">
              <label>Contraseña</label>
              <input
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="••••••••"
              />
            </div>

            <button
              className="btn lg"
              type="submit"
              disabled={loading}
              style={{ width: "100%", marginTop: 8 }}
            >
              {loading ? "CREANDO…" : "CREAR Y JUGAR"}
            </button>
          </form>
        )}

        {error && <div className="toast-error">▸ {error}_</div>}

        <div className="auth-divider">O CONTINÚA CON</div>
        <div className="social">
          <button
            className="btn ghost"
            type="button"
            onClick={() => handleOAuth("google")}
          >
            ◆ GOOGLE
          </button>
          <button
            className="btn ghost"
            type="button"
            onClick={() => handleOAuth("github")}
          >
            ▣ GITHUB
          </button>
        </div>

        <div
          style={{
            marginTop: 18,
            textAlign: "center",
            fontSize: 11,
            color: "var(--ink-faint)",
            letterSpacing: "0.1em",
          }}
        >
          AL ENTRAR ACEPTAS LOS TÉRMINOS DEL SALÓN ARCADE
        </div>
      </div>
    </div>
  );
}
