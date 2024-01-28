const resourceName = window.GetParentResourceName();

window.addEventListener("message", (event) => {
    if (event.data.type === "enableui") {
        document.body.classList[event.data.enable ? "remove" : "add"]("none");
    }
});

document.querySelector("#register").addEventListener("submit", (event) => {
    event.preventDefault();

    const dofVal = document.querySelector("#dateofbirth").value;
    if (!dofVal) return;

    const dateCheck = new Date(dofVal);

    const year = new Intl.DateTimeFormat("en", { year: "numeric" }).format(dateCheck);
    const month = new Intl.DateTimeFormat("en", { month: "2-digit" }).format(dateCheck);
    const day = new Intl.DateTimeFormat("en", { day: "2-digit" }).format(dateCheck);

    const formattedDate = `${day}/${month}/${year}`;
    fetch(`https://${resourceName}/register`, {
        method: "POST",
        body: JSON.stringify({
            firstName: document.querySelector("#firstname").value,
            lastName: document.querySelector("#lastname").value,
            dateOfBirth: formattedDate,
            sex: document.querySelector("input[type='radio'][name='sex']:checked").value,
            height: document.querySelector("#height").value,
        }),
    });

    document.querySelector("#register").reset();
});

document.addEventListener("DOMContentLoaded", () => {
    fetch(`https://${resourceName}/ready`, {
        method: "POST",
        body: JSON.stringify({}),
    });
});