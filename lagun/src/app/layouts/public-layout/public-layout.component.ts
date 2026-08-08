import { Component, OnInit, OnDestroy, inject } from "@angular/core";
import { Router, RouterOutlet, NavigationEnd } from "@angular/router";
import { NavbarComponent } from "../../shared/ui/navbar/navbar.component";
import { FooterComponent } from "../../shared/ui/footer/footer.component";
import { filter, Subscription } from "rxjs";

@Component({
  selector: "lagun-public-layout",
  standalone: true,
  imports: [RouterOutlet, NavbarComponent, FooterComponent],
  template: `
    <div class="min-h-screen bg-[#05010d] text-white relative flex flex-col overflow-x-hidden">
      <div class="absolute inset-0 bg-[url('https://grainy-gradients.vercel.app/noise.svg')] opacity-[0.03] brightness-50 contrast-150 pointer-events-none z-0"></div>

      <div class="pointer-events-none absolute inset-0 z-0
        bg-[radial-gradient(circle_at_top_left,rgba(0,229,255,0.07),transparent_35%),
             radial-gradient(circle_at_top_right,rgba(255,44,223,0.07),transparent_35%),
             radial-gradient(circle_at_bottom_left,rgba(124,58,237,0.05),transparent_40%)]">
      </div>

      <app-navbar class="relative z-50"></app-navbar>

      <main class="relative z-10 flex-grow">
        <router-outlet></router-outlet>
      </main>

      <app-footer class="relative z-10"></app-footer>
    </div>
  `,
})
export class PublicLayoutComponent implements OnInit, OnDestroy {
  private router = inject(Router);
  private navigationSub?: Subscription;

  ngOnInit() {
    this.navigationSub = this.router.events
      .pipe(filter((event) => event instanceof NavigationEnd))
      .subscribe(() => {
        window.scrollTo({
          top: 0,
          left: 0,
          behavior: "instant" as ScrollBehavior
        });

        document.documentElement.scrollTop = 0;
        document.body.scrollTop = 0;
      });
  }

  ngOnDestroy() {
    this.navigationSub?.unsubscribe();
  }
}