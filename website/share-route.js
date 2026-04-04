const requestedPath = (() => {
  const params = new URLSearchParams(window.location.search);
  const redirectedTarget = params.get("target");
  return redirectedTarget || window.location.pathname;
})();

const pathParts = requestedPath.split("/").filter(Boolean);
const routeKind = pathParts[0] || "post";
const routeID = pathParts[1] || "";

const customSchemeRoute = (() => {
  switch (routeKind) {
    case "cars":
    case "post":
      return `empireconnect://post/${routeID}`;
    case "profile":
      return `empireconnect://profile/${routeID}`;
    case "meet":
      return `empireconnect://meet/${routeID}`;
    default:
      return "empireconnect://";
  }
})();

document.querySelectorAll("[data-open-app]").forEach((node) => {
  node.setAttribute("href", customSchemeRoute);
  node.addEventListener("click", () => {
    window.location.href = customSchemeRoute;
  });
});

document.querySelectorAll(".reveal").forEach((item) => {
  item.classList.add("is-visible");
});
